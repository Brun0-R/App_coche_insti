import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show prefsService, variableStore;
import '../models/sign.dart';
import '../models/telemetry_config.dart';
import '../services/action_executor.dart';
import '../services/bluetooth_service.dart';
import '../services/sign_repository.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/sign_simulator.dart';
import '../widgets/telemetry_dashboard.dart';
import 'library_screen.dart';

class AutoScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final SignRepository repository;
  final ActionExecutor executor;
  final String deviceName;

  const AutoScreen({
    super.key,
    required this.bluetoothService,
    required this.repository,
    required this.executor,
    required this.deviceName,
  });

  @override
  State<AutoScreen> createState() => _AutoScreenState();
}

class _AutoScreenState extends State<AutoScreen> {
  StreamSubscription<int>? _signSub;
  Sign? _activeSign;
  bool _paused = false;
  bool _editing = false;
  TelemetryItem? _selected;
  late TelemetryConfig _config;

  bool get _isDemoMode =>
      !widget.bluetoothService.isConnected &&
      widget.deviceName == 'Modo demo';

  @override
  void initState() {
    super.initState();
    prefsService.lastMode = 'auto';
    _config = TelemetryConfig.fromJsonString(prefsService.telemetryConfigJson);
    widget.bluetoothService.onDisconnected = _onDisconnected;
    _signSub = widget.bluetoothService.detectedSignStream.listen(_onSignDetected);
    widget.executor.addListener(_onExecutorChanged);
  }

  @override
  void dispose() {
    widget.executor.removeListener(_onExecutorChanged);
    widget.executor.cancel();
    _signSub?.cancel();
    widget.bluetoothService.onDisconnected = null;
    super.dispose();
  }

  void _onExecutorChanged() {
    if (mounted) setState(() {});
  }

  void _onDisconnected() {
    if (!mounted || _isDemoMode) return;
    widget.executor.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conexion perdida'),
        backgroundColor: Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onSignDetected(int id) {
    if (_paused) return;
    if (id <= 0) return;
    final sign = widget.repository.byId(id);
    if (sign == null) return;
    setState(() => _activeSign = sign);
    if (sign.sequence.isNotEmpty) {
      widget.executor.run(sign.sequence);
    }
  }

  void _toggleControl() {
    if (_paused) {
      setState(() => _paused = false);
    } else {
      widget.executor.cancel();
      setState(() => _paused = true);
    }
  }

  void _exit() {
    widget.executor.cancel();
    Navigator.of(context).pop();
  }

  void _openLibrary() {
    widget.executor.cancel();
    setState(() => _paused = true);
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => LibraryScreen(
            bluetoothService: widget.bluetoothService,
            executor: widget.executor,
          ),
        ))
        .then((_) => setState(() => _paused = false));
  }

  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      if (!_editing) _selected = null;
    });
    if (!_editing) {
      prefsService.telemetryConfigJson = _config.toJsonString();
    }
  }

  void _resetLayout() {
    setState(() {
      _config = TelemetryConfig.defaultConfig();
      _selected = null;
    });
    prefsService.telemetryConfigJson = _config.toJsonString();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      floatingActionButton: _isDemoMode
          ? SignSimulatorButton(
              bluetoothService: widget.bluetoothService,
              repository: widget.repository,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SafeArea(
        child: Stack(
          children: [
            // Dashboard ocupa toda la pantalla
            Positioned.fill(
              child: TelemetryDashboard(
                config: _config,
                state: widget.executor.value,
                activeSign: _activeSign,
                bluetoothService: widget.bluetoothService,
                variables: variableStore,
                editing: _editing,
                selected: _selected,
                onTap: (item) => setState(() => _selected = item),
                onMove: (item, frac) => setState(() {
                  item.positionFrac = frac;
                }),
              ),
            ),

            // Cabecera
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  ConnectionIndicator(
                    isConnected: _isDemoMode
                        ? false
                        : widget.bluetoothService.isConnected,
                    deviceName: widget.deviceName,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          _paused ? 'AUTO PAUSA' : 'AUTO',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleEditing,
                    icon: Icon(
                        _editing ? Icons.check : Icons.dashboard_customize,
                        size: 20),
                    color: _editing ? accent : Colors.white54,
                    tooltip: _editing
                        ? 'Guardar disposicion'
                        : 'Editar dashboard',
                  ),
                  IconButton(
                    onPressed: _openLibrary,
                    icon: const Icon(Icons.library_books_outlined, size: 20),
                    color: Colors.white54,
                    tooltip: 'Biblioteca',
                  ),
                  IconButton(
                    onPressed: _exit,
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.white54,
                    tooltip: 'Salir',
                  ),
                ],
              ),
            ),

            // Panel de edicion del item seleccionado
            if (_editing && _selected != null)
              Positioned(
                bottom: 70,
                left: 16,
                right: 16,
                child: _buildEditPanel(),
              ),

            // Boton tomar control / restablecer
            if (!_editing)
              Positioned(
                bottom: 8,
                left: 16,
                right: 16,
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _toggleControl,
                    style: FilledButton.styleFrom(
                      backgroundColor: _paused ? accent : Colors.white12,
                      foregroundColor:
                          _paused ? Colors.black : Colors.white,
                    ),
                    icon: Icon(
                        _paused ? Icons.play_arrow : Icons.pan_tool, size: 18),
                    label: Text(
                      _paused ? 'REANUDAR AUTO' : 'TOMAR CONTROL',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 8,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _resetLayout,
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Restablecer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side:
                            const BorderSide(color: Color(0xFF3A3A3A)),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _toggleEditing,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Listo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditPanel() {
    final s = _selected!;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Icon(s.kind.icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Text(
            s.kind.label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Text('Tamano',
                    style: TextStyle(fontSize: 11, color: Colors.white54)),
                Expanded(
                  child: Slider(
                    value: s.scale,
                    min: 0.5,
                    max: 2.0,
                    onChanged: (v) => setState(() => s.scale = v),
                  ),
                ),
                Text('${(s.scale * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => setState(() => s.visible = !s.visible),
            icon: Icon(
                s.visible ? Icons.visibility : Icons.visibility_off,
                size: 18),
            color: s.visible ? accent : Colors.white38,
            tooltip: s.visible ? 'Ocultar' : 'Mostrar',
          ),
        ],
      ),
    );
  }
}
