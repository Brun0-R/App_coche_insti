import 'dart:async';
import 'package:flutter/material.dart';
import '../models/macro.dart';
import '../services/bluetooth_service.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/direction_indicator.dart';
import '../widgets/connection_indicator.dart';

/// Pantalla para grabar una macro conduciendo con el joystick.
/// Muestrea X/Y cada 50ms desde que pulsas REC hasta que pulsas STOP.
/// Si no hay Bluetooth conectado, igual graba (no envia comandos).
class MacroRecorderScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final Macro? existing;

  const MacroRecorderScreen({
    super.key,
    required this.bluetoothService,
    this.existing,
  });

  @override
  State<MacroRecorderScreen> createState() => _MacroRecorderScreenState();
}

class _MacroRecorderScreenState extends State<MacroRecorderScreen> {
  static const _sampleIntervalMs = 50;

  bool _recording = false;
  Timer? _sampleTimer;
  int _startMs = 0;
  int _currentX = 0;
  int _currentY = 0;
  final List<MacroSample> _samples = [];

  @override
  void dispose() {
    _sampleTimer?.cancel();
    if (widget.bluetoothService.isConnected) {
      widget.bluetoothService.sendStop();
    }
    super.dispose();
  }

  void _onJoystick(Offset normalized) {
    final x = (normalized.dx * 255).round();
    final y = (normalized.dy * 255).round();
    setState(() {
      _currentX = x;
      _currentY = y;
    });
    if (widget.bluetoothService.isConnected) {
      widget.bluetoothService.sendCommand(x, y);
    }
  }

  void _onJoystickReleased() {
    setState(() {
      _currentX = 0;
      _currentY = 0;
    });
    if (widget.bluetoothService.isConnected) {
      widget.bluetoothService.sendStop();
    }
  }

  void _toggleRecord() {
    if (_recording) {
      _sampleTimer?.cancel();
      setState(() => _recording = false);
    } else {
      _samples.clear();
      _startMs = DateTime.now().millisecondsSinceEpoch;
      _sampleTimer = Timer.periodic(
          const Duration(milliseconds: _sampleIntervalMs), _sample);
      setState(() => _recording = true);
    }
  }

  void _sample(Timer _) {
    final t = DateTime.now().millisecondsSinceEpoch - _startMs;
    _samples.add(MacroSample(t, _currentX, _currentY));
    setState(() {});
  }

  Future<void> _save() async {
    if (_samples.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final controller =
        TextEditingController(text: widget.existing?.name ?? 'Macro');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Guardar macro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (name == null) {
      Navigator.of(context).pop();
      return;
    }
    final macro = Macro(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.isEmpty ? 'Macro' : name,
      samples: List.of(_samples),
    );
    Navigator.of(context).pop(macro);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final joystickSize = size.height * 0.65;
    final connected = widget.bluetoothService.isConnected;
    final demo = !connected;
    final durationS =
        _samples.isEmpty ? 0.0 : _samples.last.t / 1000;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Panel izquierdo: estado + REC
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        ConnectionIndicator(
                          isConnected: connected,
                          deviceName:
                              connected ? 'Coche' : 'Modo demo',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: Colors.white38,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _recording
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _recording
                                ? Colors.redAccent
                                : const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _recording
                                ? Icons.fiber_manual_record
                                : Icons.fiber_manual_record_outlined,
                            color: _recording
                                ? Colors.redAccent
                                : Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _recording ? 'GRABANDO' : 'EN ESPERA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _recording
                                  ? Colors.redAccent
                                  : Colors.white54,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        DirectionIndicator(x: _currentX, y: _currentY),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_samples.length} puntos',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontFamily: 'monospace')),
                            Text('${durationS.toStringAsFixed(1)}s',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white54,
                                    fontFamily: 'monospace')),
                            Text('X:$_currentX  Y:$_currentY',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                    if (demo)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'DEMO - graba sin enviar al coche',
                            style: TextStyle(
                                fontSize: 10, color: Colors.amber),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _toggleRecord,
                            icon: Icon(_recording
                                ? Icons.stop
                                : Icons.fiber_manual_record),
                            label: Text(_recording
                                ? 'DETENER'
                                : 'GRABAR'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _recording
                                  ? Colors.redAccent
                                  : accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed:
                              _samples.isEmpty || _recording ? null : _save,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                          ),
                          child: const Text('GUARDAR'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Panel derecho: joystick
            Expanded(
              flex: 3,
              child: Center(
                child: JoystickWidget(
                  size: joystickSize,
                  onChanged: _onJoystick,
                  onReleased: _onJoystickReleased,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
