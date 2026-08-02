import 'package:flutter/material.dart';
import '../main.dart' show prefsService, signRepository;
import '../services/action_executor.dart';
import '../services/bluetooth_service.dart';
import '../services/preferences_service.dart' show OverlayProfile;
import '../widgets/connection_indicator.dart';
import '../widgets/direction_indicator.dart';
import '../widgets/joystick_editor.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/overlay_editor.dart';
import '../widgets/sign_overlay.dart';
import '../widgets/sign_simulator.dart';
import '../widgets/speed_selector.dart';
import 'auto_screen.dart';
import 'library_screen.dart';
import 'tank_screen.dart';

class ControlScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final ActionExecutor executor;
  final String deviceName;

  const ControlScreen({
    super.key,
    required this.bluetoothService,
    required this.executor,
    required this.deviceName,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late int _speedPercent;
  int _currentX = 0;
  int _currentY = 0;
  late bool _connected;
  bool _isEditing = false;
  bool _isEditingOverlay = false;
  late JoystickConfig _joystickConfig;
  late Offset _overlayFrac;
  late double _overlayScale;

  bool get _isDemoMode =>
      !widget.bluetoothService.isConnected &&
      widget.deviceName == 'Modo demo';

  @override
  void initState() {
    super.initState();
    _connected = widget.bluetoothService.isConnected;
    _speedPercent = prefsService.speedPercent;
    _joystickConfig = prefsService.joystickConfig;
    _overlayFrac = prefsService.overlayPositionFrac(OverlayProfile.joystick);
    _overlayScale = prefsService.overlayScale(OverlayProfile.joystick);
    widget.bluetoothService.onDisconnected = _onDisconnected;

    // Aplicar el algoritmo del HuskyLens guardado al conectar.
    if (widget.bluetoothService.isConnected) {
      widget.bluetoothService.sendAlgorithm(prefsService.huskyAlgorithm);
    }

    prefsService.lastMode = 'joystick';
  }

  @override
  void dispose() {
    widget.bluetoothService.onDisconnected = null;
    super.dispose();
  }

  void _onDisconnected() {
    if (!mounted || _isDemoMode) return;
    setState(() => _connected = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conexion perdida con el dispositivo'),
        backgroundColor: Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onInputChanged(Offset normalized) {
    final multiplier = _speedPercent / 100.0;
    final x = (normalized.dx * 255 * multiplier).round();
    final y = (normalized.dy * 255 * multiplier).round();
    setState(() {
      _currentX = x;
      _currentY = y;
    });
    if (!_isDemoMode) widget.bluetoothService.sendCommand(x, y);
  }

  void _onInputReleased() {
    setState(() {
      _currentX = 0;
      _currentY = 0;
    });
    if (!_isDemoMode) widget.bluetoothService.sendStop();
  }

  void _disconnect() {
    if (!_isDemoMode) {
      widget.bluetoothService.sendStop();
      widget.bluetoothService.disconnect();
    }
    Navigator.of(context).pop();
  }

  void _openTankMode() {
    _onInputReleased();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TankScreen(
        bluetoothService: widget.bluetoothService,
        executor: widget.executor,
        deviceName: widget.deviceName,
      ),
    ));
  }

  void _openAutoMode() {
    _onInputReleased();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AutoScreen(
        bluetoothService: widget.bluetoothService,
        repository: signRepository,
        executor: widget.executor,
        deviceName: widget.deviceName,
      ),
    ));
  }

  void _openLibrary({int initialTab = 0}) {
    _onInputReleased();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LibraryScreen(
        bluetoothService: widget.bluetoothService,
        executor: widget.executor,
        initialTab: initialTab,
      ),
    ));
  }

  void _onSpeedChanged(int v) {
    setState(() => _speedPercent = v);
    prefsService.speedPercent = v;
  }

  void _onEditorDone() {
    setState(() => _isEditing = false);
    prefsService.joystickConfig = _joystickConfig;
  }

  Future<void> _showMenu() async {
    final accent = Theme.of(context).colorScheme.primary;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.library_books_outlined, color: accent),
              title: const Text('Biblioteca'),
              subtitle: const Text(
                  'Senales, programas, macros, algoritmos',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openLibrary();
              },
            ),
            ListTile(
              leading: Icon(Icons.crop_free, color: accent),
              title: const Text('Editar overlay de senal'),
              subtitle: const Text(
                  'Mover el chip que aparece al detectar una senal',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                setState(() => _isEditingOverlay = true);
              },
            ),
            ListTile(
              leading: Icon(Icons.tune, color: accent),
              title: const Text('Editar joystick'),
              subtitle: const Text('Posicion y tamano del joystick',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                setState(() => _isEditing = true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isDemoMode
          ? SignSimulatorButton(
              bluetoothService: widget.bluetoothService,
              repository: signRepository,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Row(
                  children: [
                    _buildLeftPanel(),
                    _buildRightPanel(),
                  ],
                ),
                positionedOverlay(
                  positionFrac: _overlayFrac,
                  screenSize: screenSize,
                  child: SignOverlay(
                    bluetoothService: widget.bluetoothService,
                    repository: signRepository,
                    scale: _overlayScale,
                  ),
                ),
                if (_isEditing)
                  Positioned.fill(
                    child: JoystickEditor(
                      config: _joystickConfig,
                      deviceName: widget.deviceName,
                      isDemoMode: _isDemoMode,
                      onChanged: (c) => setState(() {
                        _joystickConfig.position = c.position;
                        _joystickConfig.sizeFactor = c.sizeFactor;
                      }),
                      onDone: _onEditorDone,
                    ),
                  ),
                if (_isEditingOverlay)
                  Positioned.fill(
                    child: OverlayEditor(
                      initialPositionFrac: _overlayFrac,
                      initialScale: _overlayScale,
                      onCancel: () =>
                          setState(() => _isEditingOverlay = false),
                      onDone: (frac, scale) {
                        setState(() {
                          _overlayFrac = frac;
                          _overlayScale = scale;
                          _isEditingOverlay = false;
                        });
                        prefsService.setOverlayPositionFrac(
                            OverlayProfile.joystick, frac);
                        prefsService.setOverlayScale(
                            OverlayProfile.joystick, scale);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    final accent = Theme.of(context).colorScheme.primary;

    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cabecera: conexion + menu + logout
            Row(
              children: [
                Expanded(
                  child: ConnectionIndicator(
                    isConnected: _isDemoMode ? false : _connected,
                    deviceName: widget.deviceName,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu, size: 22),
                  color: Colors.white70,
                  tooltip: 'Menu',
                  onPressed: _showMenu,
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  color: Colors.white38,
                  tooltip: _isDemoMode ? 'Volver' : 'Desconectar',
                  onPressed: _disconnect,
                ),
              ],
            ),

            if (_isDemoMode)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'DEMO - No se envian datos',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber,
                      fontWeight: FontWeight.w500),
                ),
              ),

            const SizedBox(height: 20),

            // Selector de modo: chips
            const Text(
              'MODO',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _modeChip(
                  label: 'Joystick',
                  icon: Icons.gamepad,
                  active: true,
                  onTap: () {},
                  accent: accent,
                ),
                const SizedBox(width: 8),
                _modeChip(
                  label: 'Dual',
                  icon: Icons.tune,
                  active: false,
                  onTap: _openTankMode,
                  accent: accent,
                ),
                const SizedBox(width: 8),
                _modeChip(
                  label: 'Auto',
                  icon: Icons.auto_awesome,
                  active: false,
                  onTap: _openAutoMode,
                  accent: accent,
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              'VELOCIDAD',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 10),
            SpeedSelector(
              selected: _speedPercent,
              onChanged: _onSpeedChanged,
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                DirectionIndicator(x: _currentX, y: _currentY),
                const SizedBox(width: 12),
                Text(
                  'X:$_currentX  Y:$_currentY',
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: active
              ? null
              : Border.all(color: const Color(0xFF3A3A3A), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: active ? Colors.black : Colors.white54),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.black : Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    final screenHeight = MediaQuery.of(context).size.height;
    final joystickSize = screenHeight * _joystickConfig.sizeFactor;
    return Expanded(
      flex: 3,
      child: Center(
        child: Transform.translate(
          offset: _joystickConfig.position,
          child: JoystickWidget(
            size: joystickSize,
            onChanged: _onInputChanged,
            onReleased: _onInputReleased,
          ),
        ),
      ),
    );
  }
}
