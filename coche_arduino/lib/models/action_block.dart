import 'package:flutter/material.dart';

enum MoveKind {
  forward,
  backward,
  brake,
  turnLeft,
  turnRight,
  pivotLeft,
  pivotRight,
}

extension MoveKindLabel on MoveKind {
  String get label {
    switch (this) {
      case MoveKind.forward:
        return 'Avanzar';
      case MoveKind.backward:
        return 'Retroceder';
      case MoveKind.brake:
        return 'Frenar';
      case MoveKind.turnLeft:
        return 'Curva izquierda';
      case MoveKind.turnRight:
        return 'Curva derecha';
      case MoveKind.pivotLeft:
        return 'Pivotar izq';
      case MoveKind.pivotRight:
        return 'Pivotar der';
    }
  }

  IconData get icon {
    switch (this) {
      case MoveKind.forward:
        return Icons.arrow_upward;
      case MoveKind.backward:
        return Icons.arrow_downward;
      case MoveKind.brake:
        return Icons.stop_circle_outlined;
      case MoveKind.turnLeft:
        return Icons.turn_slight_left;
      case MoveKind.turnRight:
        return Icons.turn_slight_right;
      case MoveKind.pivotLeft:
        return Icons.rotate_left;
      case MoveKind.pivotRight:
        return Icons.rotate_right;
    }
  }
}

enum RawMode { xy, tank }

sealed class ActionBlock {
  Map<String, dynamic> toJson();

  static ActionBlock fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'move':
        return MoveBlock.fromJson(json);
      case 'raw':
        return RawMotorBlock.fromJson(json);
      case 'delay':
        return DelayBlock.fromJson(json);
      case 'random_delay':
        return RandomDelayBlock.fromJson(json);
      case 'speed':
        return SpeedBlock.fromJson(json);
      case 'repeat':
        return RepeatBlock.fromJson(json);
      case 'while_forever':
        return WhileForeverBlock.fromJson(json);
      case 'if_sign':
        return IfSignBlock.fromJson(json);
      case 'wait_for_sign':
        return WaitForSignBlock.fromJson(json);
      case 'random':
        return RandomBlock.fromJson(json);
      case 'set_var':
        return SetVarBlock.fromJson(json);
      case 'change_var':
        return ChangeVarBlock.fromJson(json);
      case 'if_var':
        return IfVarBlock.fromJson(json);
      case 'run_program':
        return RunProgramBlock.fromJson(json);
      case 'run_macro':
        return RunMacroBlock.fromJson(json);
      case 'stop_all':
        return StopAllBlock();
      default:
        throw FormatException('Tipo de bloque desconocido: $type');
    }
  }

  ActionBlock copy();
}

class MoveBlock extends ActionBlock {
  MoveKind kind;
  int? durationMs;

  MoveBlock({required this.kind, this.durationMs});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'move',
        'kind': kind.name,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory MoveBlock.fromJson(Map<String, dynamic> json) => MoveBlock(
        kind: MoveKind.values.firstWhere((k) => k.name == json['kind']),
        durationMs: json['durationMs'] as int?,
      );

  @override
  MoveBlock copy() => MoveBlock(kind: kind, durationMs: durationMs);
}

class RawMotorBlock extends ActionBlock {
  RawMode mode;
  // Para xy: a = X, b = Y. Para tank: a = izq, b = der. Rango -255..255.
  int a;
  int b;
  int? durationMs;

  RawMotorBlock({
    required this.mode,
    required this.a,
    required this.b,
    this.durationMs,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'raw',
        'mode': mode.name,
        'a': a,
        'b': b,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory RawMotorBlock.fromJson(Map<String, dynamic> json) => RawMotorBlock(
        mode: RawMode.values.firstWhere((m) => m.name == json['mode']),
        a: json['a'] as int,
        b: json['b'] as int,
        durationMs: json['durationMs'] as int?,
      );

  @override
  RawMotorBlock copy() =>
      RawMotorBlock(mode: mode, a: a, b: b, durationMs: durationMs);
}

class DelayBlock extends ActionBlock {
  int ms;

  DelayBlock({required this.ms});

  @override
  Map<String, dynamic> toJson() => {'type': 'delay', 'ms': ms};

  factory DelayBlock.fromJson(Map<String, dynamic> json) =>
      DelayBlock(ms: json['ms'] as int);

  @override
  DelayBlock copy() => DelayBlock(ms: ms);
}

class SpeedBlock extends ActionBlock {
  int percent;

  SpeedBlock({required this.percent});

  @override
  Map<String, dynamic> toJson() => {'type': 'speed', 'percent': percent};

  factory SpeedBlock.fromJson(Map<String, dynamic> json) =>
      SpeedBlock(percent: json['percent'] as int);

  @override
  SpeedBlock copy() => SpeedBlock(percent: percent);
}

class RepeatBlock extends ActionBlock {
  int times;
  List<ActionBlock> children;

  RepeatBlock({required this.times, required this.children});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'repeat',
        'times': times,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory RepeatBlock.fromJson(Map<String, dynamic> json) => RepeatBlock(
        times: json['times'] as int,
        children: (json['children'] as List)
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  RepeatBlock copy() => RepeatBlock(
        times: times,
        children: children.map((c) => c.copy()).toList(),
      );
}

class StopAllBlock extends ActionBlock {
  @override
  Map<String, dynamic> toJson() => {'type': 'stop_all'};

  @override
  StopAllBlock copy() => StopAllBlock();
}

class RandomDelayBlock extends ActionBlock {
  int minMs;
  int maxMs;

  RandomDelayBlock({required this.minMs, required this.maxMs});

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'random_delay', 'minMs': minMs, 'maxMs': maxMs};

  factory RandomDelayBlock.fromJson(Map<String, dynamic> json) =>
      RandomDelayBlock(
        minMs: json['minMs'] as int,
        maxMs: json['maxMs'] as int,
      );

  @override
  RandomDelayBlock copy() => RandomDelayBlock(minMs: minMs, maxMs: maxMs);
}

class WhileForeverBlock extends ActionBlock {
  List<ActionBlock> children;

  WhileForeverBlock({required this.children});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'while_forever',
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory WhileForeverBlock.fromJson(Map<String, dynamic> json) =>
      WhileForeverBlock(
        children: (json['children'] as List)
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  WhileForeverBlock copy() =>
      WhileForeverBlock(children: children.map((c) => c.copy()).toList());
}

class IfSignBlock extends ActionBlock {
  /// 0 = "cualquier senal visible", >0 = id concreto
  int signId;
  List<ActionBlock> thenChildren;
  List<ActionBlock> elseChildren;

  IfSignBlock({
    required this.signId,
    required this.thenChildren,
    required this.elseChildren,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'if_sign',
        'signId': signId,
        'then': thenChildren.map((c) => c.toJson()).toList(),
        'else': elseChildren.map((c) => c.toJson()).toList(),
      };

  factory IfSignBlock.fromJson(Map<String, dynamic> json) => IfSignBlock(
        signId: json['signId'] as int,
        thenChildren: (json['then'] as List)
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
        elseChildren: (json['else'] as List? ?? [])
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  IfSignBlock copy() => IfSignBlock(
        signId: signId,
        thenChildren: thenChildren.map((c) => c.copy()).toList(),
        elseChildren: elseChildren.map((c) => c.copy()).toList(),
      );
}

class WaitForSignBlock extends ActionBlock {
  /// 0 = "cualquier senal", >0 = id concreto
  int signId;
  int? timeoutMs;

  WaitForSignBlock({required this.signId, this.timeoutMs});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'wait_for_sign',
        'signId': signId,
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
      };

  factory WaitForSignBlock.fromJson(Map<String, dynamic> json) =>
      WaitForSignBlock(
        signId: json['signId'] as int,
        timeoutMs: json['timeoutMs'] as int?,
      );

  @override
  WaitForSignBlock copy() =>
      WaitForSignBlock(signId: signId, timeoutMs: timeoutMs);
}

class RandomBlock extends ActionBlock {
  List<ActionBlock> children;

  RandomBlock({required this.children});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'random',
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory RandomBlock.fromJson(Map<String, dynamic> json) => RandomBlock(
        children: (json['children'] as List)
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  RandomBlock copy() =>
      RandomBlock(children: children.map((c) => c.copy()).toList());
}

enum CompareOp { eq, ne, lt, le, gt, ge }

extension CompareOpLabel on CompareOp {
  String get symbol {
    switch (this) {
      case CompareOp.eq:
        return '==';
      case CompareOp.ne:
        return '!=';
      case CompareOp.lt:
        return '<';
      case CompareOp.le:
        return '<=';
      case CompareOp.gt:
        return '>';
      case CompareOp.ge:
        return '>=';
    }
  }

  bool apply(int a, int b) {
    switch (this) {
      case CompareOp.eq:
        return a == b;
      case CompareOp.ne:
        return a != b;
      case CompareOp.lt:
        return a < b;
      case CompareOp.le:
        return a <= b;
      case CompareOp.gt:
        return a > b;
      case CompareOp.ge:
        return a >= b;
    }
  }
}

/// Asigna un valor a una variable. Nombre con `$` al principio = global.
class SetVarBlock extends ActionBlock {
  String name;
  int value;

  SetVarBlock({required this.name, required this.value});

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'set_var', 'name': name, 'value': value};

  factory SetVarBlock.fromJson(Map<String, dynamic> json) => SetVarBlock(
        name: json['name'] as String,
        value: json['value'] as int,
      );

  @override
  SetVarBlock copy() => SetVarBlock(name: name, value: value);
}

/// Suma `delta` a la variable (puede ser negativo).
class ChangeVarBlock extends ActionBlock {
  String name;
  int delta;

  ChangeVarBlock({required this.name, required this.delta});

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'change_var', 'name': name, 'delta': delta};

  factory ChangeVarBlock.fromJson(Map<String, dynamic> json) => ChangeVarBlock(
        name: json['name'] as String,
        delta: json['delta'] as int,
      );

  @override
  ChangeVarBlock copy() => ChangeVarBlock(name: name, delta: delta);
}

/// Si variable OP valor, ejecuta thenChildren, si no elseChildren.
class IfVarBlock extends ActionBlock {
  String name;
  CompareOp op;
  int value;
  List<ActionBlock> thenChildren;
  List<ActionBlock> elseChildren;

  IfVarBlock({
    required this.name,
    required this.op,
    required this.value,
    required this.thenChildren,
    required this.elseChildren,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'if_var',
        'name': name,
        'op': op.name,
        'value': value,
        'then': thenChildren.map((c) => c.toJson()).toList(),
        'else': elseChildren.map((c) => c.toJson()).toList(),
      };

  factory IfVarBlock.fromJson(Map<String, dynamic> json) => IfVarBlock(
        name: json['name'] as String,
        op: CompareOp.values.firstWhere((o) => o.name == json['op']),
        value: json['value'] as int,
        thenChildren: (json['then'] as List)
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
        elseChildren: (json['else'] as List? ?? [])
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  IfVarBlock copy() => IfVarBlock(
        name: name,
        op: op,
        value: value,
        thenChildren: thenChildren.map((c) => c.copy()).toList(),
        elseChildren: elseChildren.map((c) => c.copy()).toList(),
      );
}

/// Llama a un programa guardado por id.
class RunProgramBlock extends ActionBlock {
  String programId;

  RunProgramBlock({required this.programId});

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'run_program', 'programId': programId};

  factory RunProgramBlock.fromJson(Map<String, dynamic> json) =>
      RunProgramBlock(programId: json['programId'] as String);

  @override
  RunProgramBlock copy() => RunProgramBlock(programId: programId);
}

/// Reproduce una macro grabada por id.
class RunMacroBlock extends ActionBlock {
  String macroId;

  RunMacroBlock({required this.macroId});

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'run_macro', 'macroId': macroId};

  factory RunMacroBlock.fromJson(Map<String, dynamic> json) =>
      RunMacroBlock(macroId: json['macroId'] as String);

  @override
  RunMacroBlock copy() => RunMacroBlock(macroId: macroId);
}

String describeBlock(ActionBlock block) {
  switch (block) {
    case MoveBlock(:final kind, :final durationMs):
      return durationMs == null
          ? kind.label
          : '${kind.label} (${durationMs}ms)';
    case RawMotorBlock(:final mode, :final a, :final b, :final durationMs):
      final etiqueta = mode == RawMode.xy ? 'X:$a Y:$b' : 'IZQ:$a DER:$b';
      return durationMs == null ? etiqueta : '$etiqueta (${durationMs}ms)';
    case DelayBlock(:final ms):
      return 'Esperar ${ms}ms';
    case RandomDelayBlock(:final minMs, :final maxMs):
      return 'Esperar entre $minMs-${maxMs}ms';
    case SpeedBlock(:final percent):
      return 'Velocidad $percent%';
    case RepeatBlock(:final times, :final children):
      return 'Repetir x$times (${children.length} bloques)';
    case WhileForeverBlock(:final children):
      return 'Bucle infinito (${children.length} bloques)';
    case IfSignBlock(:final signId, :final thenChildren, :final elseChildren):
      final cond = signId == 0 ? 'cualquier senal' : 'senal #$signId';
      return 'Si $cond -> ${thenChildren.length}, si no -> ${elseChildren.length}';
    case WaitForSignBlock(:final signId, :final timeoutMs):
      final cond = signId == 0 ? 'cualquier senal' : 'senal #$signId';
      return timeoutMs == null
          ? 'Esperar a $cond'
          : 'Esperar a $cond (max ${timeoutMs}ms)';
    case RandomBlock(:final children):
      return 'Aleatorio entre ${children.length} bloques';
    case SetVarBlock(:final name, :final value):
      return '$name = $value';
    case ChangeVarBlock(:final name, :final delta):
      return delta >= 0 ? '$name += $delta' : '$name -= ${-delta}';
    case IfVarBlock(:final name, :final op, :final value, :final thenChildren, :final elseChildren):
      return 'Si $name ${op.symbol} $value -> ${thenChildren.length} / ${elseChildren.length}';
    case RunProgramBlock(:final programId):
      return 'Ejecutar programa #$programId';
    case RunMacroBlock(:final macroId):
      return 'Reproducir macro #$macroId';
    case StopAllBlock():
      return 'Parar todo';
  }
}

String describeSequence(List<ActionBlock> seq) {
  if (seq.isEmpty) return 'Sin acciones';
  if (seq.length == 1) return describeBlock(seq.first);
  return '${seq.length} pasos: ${describeBlock(seq.first)}...';
}
