import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/action_block.dart';
import '../models/macro.dart';
import 'bluetooth_service.dart';
import 'macro_repository.dart';
import 'program_repository.dart';
import 'variable_store.dart';

class ExecutionState {
  final ActionBlock? currentBlock;
  final int currentIndex;
  final int totalBlocks;
  final bool running;
  final int currentX;
  final int currentY;
  final int speedPercent;

  const ExecutionState({
    this.currentBlock,
    this.currentIndex = 0,
    this.totalBlocks = 0,
    this.running = false,
    this.currentX = 0,
    this.currentY = 0,
    this.speedPercent = 100,
  });

  /// Velocidad del motor izquierdo (-255..255), arcade drive.
  int get leftMotor => (currentY + currentX).clamp(-255, 255);

  /// Velocidad del motor derecho (-255..255), arcade drive.
  int get rightMotor => (currentY - currentX).clamp(-255, 255);

  static const idle = ExecutionState();
}

/// Ejecuta una secuencia de [ActionBlock] mandando comandos X/Y al
/// Arduino via [BluetoothService]. La nueva llamada a [run] cancela
/// cualquier ejecucion en curso.
class ActionExecutor extends ValueNotifier<ExecutionState> {
  final BluetoothService bluetooth;
  final VariableStore variables;
  ProgramRepository? programs;
  MacroRepository? macros;

  int _runId = 0;
  int _speedPercent;
  int _currentX = 0;
  int _currentY = 0;
  ActionBlock? _currentBlock;
  int _currentIndex = 0;
  int _totalBlocks = 0;
  int _depth = 0;
  static const _maxDepth = 16;
  final Random _random = Random();

  ActionExecutor(
    this.bluetooth,
    this.variables, {
    int initialSpeedPercent = 100,
  })  : _speedPercent = initialSpeedPercent.clamp(0, 100),
        super(ExecutionState.idle);

  void attachRepositories({
    required ProgramRepository programs,
    required MacroRepository macros,
  }) {
    this.programs = programs;
    this.macros = macros;
  }

  int get speedPercent => _speedPercent;

  Future<void> run(List<ActionBlock> blocks) async {
    final id = ++_runId;
    bluetooth.sendStop();
    _currentX = 0;
    _currentY = 0;
    _depth = 0;
    variables.resetLocals();
    if (blocks.isEmpty) {
      value = ExecutionState.idle;
      return;
    }
    await _runList(blocks, id);
    if (id == _runId) {
      bluetooth.sendStop();
      _currentX = 0;
      _currentY = 0;
      value = ExecutionState.idle;
    }
  }

  void cancel() {
    _runId++;
    bluetooth.sendStop();
    _currentX = 0;
    _currentY = 0;
    value = ExecutionState.idle;
  }

  Future<void> _runList(List<ActionBlock> blocks, int id) async {
    final previousTotal = _totalBlocks;
    _totalBlocks = blocks.length;
    for (var i = 0; i < blocks.length; i++) {
      if (id != _runId) return;
      _currentBlock = blocks[i];
      _currentIndex = i;
      _emitState();
      await _runBlock(blocks[i], id);
    }
    _totalBlocks = previousTotal;
  }

  Future<void> _runBlock(ActionBlock block, int id) async {
    switch (block) {
      case MoveBlock():
        await _runMove(block, id);
      case RawMotorBlock():
        await _runRaw(block, id);
      case DelayBlock(:final ms):
        await _wait(ms, id);
      case RandomDelayBlock(:final minMs, :final maxMs):
        final lo = minMs < maxMs ? minMs : maxMs;
        final hi = minMs < maxMs ? maxMs : minMs;
        final ms = lo + _random.nextInt((hi - lo).abs() + 1);
        await _wait(ms, id);
      case SpeedBlock(:final percent):
        _speedPercent = percent.clamp(0, 100);
        _emitState();
      case RepeatBlock(:final times, :final children):
        for (var i = 0; i < times; i++) {
          if (id != _runId) return;
          await _runList(children, id);
        }
      case WhileForeverBlock(:final children):
        var safetyTicks = 0;
        while (id == _runId) {
          if (children.isEmpty) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            if (++safetyTicks > 200) return;
            continue;
          }
          await _runList(children, id);
        }
      case IfSignBlock(:final signId, :final thenChildren, :final elseChildren):
        final seen = bluetooth.lastSeenSignId;
        final matches = signId == 0 ? seen != 0 : seen == signId;
        if (matches) {
          await _runList(thenChildren, id);
        } else {
          await _runList(elseChildren, id);
        }
      case WaitForSignBlock(:final signId, :final timeoutMs):
        await _waitForSign(signId, timeoutMs, id);
      case RandomBlock(:final children):
        if (children.isNotEmpty) {
          final pick = children[_random.nextInt(children.length)];
          await _runBlock(pick, id);
        }
      case SetVarBlock(:final name, :final value):
        variables.set(name, value);
      case ChangeVarBlock(:final name, :final delta):
        variables.change(name, delta);
      case IfVarBlock(
          :final name,
          :final op,
          :final value,
          :final thenChildren,
          :final elseChildren
        ):
        final cur = variables.get(name);
        if (op.apply(cur, value)) {
          await _runList(thenChildren, id);
        } else {
          await _runList(elseChildren, id);
        }
      case RunProgramBlock(:final programId):
        final p = programs?.byId(programId);
        if (p != null && _depth < _maxDepth) {
          _depth++;
          await _runList(p.sequence, id);
          _depth--;
        }
      case RunMacroBlock(:final macroId):
        final m = macros?.byId(macroId);
        if (m != null) {
          await _runMacro(m, id);
        }
      case StopAllBlock():
        bluetooth.sendStop();
        _runId++;
        _currentX = 0;
        _currentY = 0;
        value = ExecutionState.idle;
        return;
    }
  }

  Future<void> _runMove(MoveBlock block, int id) async {
    final xy = _moveToXY(block.kind);
    _send(xy.$1, xy.$2);
    if (block.durationMs != null) {
      await _wait(block.durationMs!, id);
      if (id == _runId) {
        bluetooth.sendStop();
        _currentX = 0;
        _currentY = 0;
        _emitState();
      }
    }
  }

  Future<void> _runRaw(RawMotorBlock block, int id) async {
    int x;
    int y;
    if (block.mode == RawMode.xy) {
      x = block.a;
      y = block.b;
    } else {
      x = ((block.a - block.b) / 2).round();
      y = ((block.a + block.b) / 2).round();
    }
    _send(x, y);
    if (block.durationMs != null) {
      await _wait(block.durationMs!, id);
      if (id == _runId) {
        bluetooth.sendStop();
        _currentX = 0;
        _currentY = 0;
        _emitState();
      }
    }
  }

  void _send(int x, int y) {
    final mult = _speedPercent / 100.0;
    final sentX = (x * mult).round();
    final sentY = (y * mult).round();
    _currentX = sentX;
    _currentY = sentY;
    bluetooth.sendCommand(sentX, sentY);
    _emitState();
  }

  Future<void> _wait(int ms, int id) async {
    if (ms <= 0) return;
    final deadline = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(deadline)) {
      if (id != _runId) return;
      final left = deadline.difference(DateTime.now()).inMilliseconds;
      if (left <= 0) return;
      await Future<void>.delayed(
          Duration(milliseconds: left > 25 ? 25 : left));
    }
  }

  Future<void> _runMacro(Macro macro, int id) async {
    if (macro.samples.isEmpty) return;
    final start = DateTime.now();
    for (final s in macro.samples) {
      if (id != _runId) return;
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final wait = s.t - elapsed;
      if (wait > 0) await _wait(wait, id);
      if (id != _runId) return;
      _send(s.x, s.y);
    }
    if (id == _runId) {
      bluetooth.sendStop();
      _currentX = 0;
      _currentY = 0;
      _emitState();
    }
  }

  Future<void> _waitForSign(int targetId, int? timeoutMs, int id) async {
    final completer = Completer<void>();
    StreamSubscription<int>? sub;
    Timer? timer;

    void finish() {
      if (!completer.isCompleted) completer.complete();
      sub?.cancel();
      timer?.cancel();
    }

    final initial = bluetooth.lastSeenSignId;
    final matches = targetId == 0 ? initial != 0 : initial == targetId;
    if (matches) return;

    sub = bluetooth.detectedSignStream.listen((seen) {
      final m = targetId == 0 ? seen != 0 : seen == targetId;
      if (m) finish();
    });

    if (timeoutMs != null && timeoutMs > 0) {
      timer = Timer(Duration(milliseconds: timeoutMs), finish);
    }

    while (!completer.isCompleted) {
      if (id != _runId) {
        sub.cancel();
        timer?.cancel();
        return;
      }
      await Future.any([
        completer.future,
        Future<void>.delayed(const Duration(milliseconds: 50)),
      ]);
    }
  }

  void _emitState() {
    value = ExecutionState(
      currentBlock: _currentBlock,
      currentIndex: _currentIndex,
      totalBlocks: _totalBlocks,
      running: _runId != 0,
      currentX: _currentX,
      currentY: _currentY,
      speedPercent: _speedPercent,
    );
  }

  (int, int) _moveToXY(MoveKind kind) {
    switch (kind) {
      case MoveKind.forward:
        return (0, 255);
      case MoveKind.backward:
        return (0, -255);
      case MoveKind.brake:
        return (0, 0);
      case MoveKind.turnLeft:
        return (-180, 180);
      case MoveKind.turnRight:
        return (180, 180);
      case MoveKind.pivotLeft:
        return (-255, 0);
      case MoveKind.pivotRight:
        return (255, 0);
    }
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
