import 'package:flutter/material.dart';
import '../main.dart' show prefsService, signRepository;
import '../services/action_executor.dart';
import '../services/bluetooth_service.dart';
import '../services/preferences_service.dart' show OverlayProfile;
import '../widgets/connection_indicator.dart';
import '../widgets/overlay_editor.dart';
import '../widgets/sign_overlay.dart';
import '../widgets/sign_simulator.dart';
import '../widgets/speed_selector.dart';
import '../widgets/direction_indicator.dart';

class TankScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final ActionExecutor executor;
  final String deviceName;

  const TankScreen({
    super.key,
    required this.bluetoothService,
    required this.executor,
    required this.deviceName,
  });

  @override
  State<TankScreen> createState() => _TankScreenState();
}

class _TankScreenState extends State<TankScreen> {
  double _leftValue = 0;
  double _rightValue = 0;
  late int _speedPercent;
  int _currentX = 0;
  int _currentY = 0;
  bool _isEditingOverlay = false;
  late Offset _overlayFrac;
  late double _overlayScale;

  bool get _isDemoMode =>
      !widget.bluetoothService.isConnected &&
      widget.deviceName == 'Modo demo';

  @override
  void initState() {
    super.initState();
    _speedPercent = prefsService.speedPercent;
    _overlayFrac = prefsService.overlayPositionFrac(OverlayProfile.dual);
    _overlayScale = prefsService.overlayScale(OverlayProfile.dual);
    prefsService.lastMode = 'dual';
    widget.bluetoothService.onDisconnected = _onDisconnected;
  }

  @override
  void dispose() {
    widget.bluetoothService.onDisconnected = null;
    super.dispose();
  }

  void _onDisconnected() {
    if (!mounted || _isDemoMode) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conexion perdida con el dispositivo'),
        backgroundColor: Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _updateCommand() {
    final multiplier = _speedPercent / 100.0;
    final rawX = (_leftValue - _rightValue) / 2;
    final rawY = (_leftValue + _rightValue) / 2;
    final x = (rawX * 255 * multiplier).round();
    final y = (rawY * 255 * multiplier).round();

    setState(() {
      _currentX = x;
      _currentY = y;
    });

    if (!_isDemoMode) {
      widget.bluetoothService.sendCommand(x, y);
    }
  }

  void _onSliderReleased(bool isLeft) {
    setState(() {
      if (isLeft) {
        _leftValue = 0;
      } else {
        _rightValue = 0;
      }
      if (_leftValue == 0 && _rightValue == 0) {
        _currentX = 0;
        _currentY = 0;
        if (!_isDemoMode) widget.bluetoothService.sendStop();
      } else {
        _updateCommand();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

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
                    _buildSideSlider(
                      value: _leftValue,
                      label: 'IZQUIERDO',
                      color: accent,
                      onChanged: (v) {
                        setState(() => _leftValue = v);
                        _updateCommand();
                      },
                      onReleased: () => _onSliderReleased(true),
                    ),
                    Expanded(flex: 3, child: _buildCenter()),
                    _buildSideSlider(
                      value: _rightValue,
                      label: 'DERECHO',
                      color: accent,
                      onChanged: (v) {
                        setState(() => _rightValue = v);
                        _updateCommand();
                      },
                      onReleased: () => _onSliderReleased(false),
                    ),
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
                            OverlayProfile.dual, frac);
                        prefsService.setOverlayScale(
                            OverlayProfile.dual, scale);
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

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ConnectionIndicator(
                isConnected:
                    _isDemoMode ? false : widget.bluetoothService.isConnected,
                deviceName: widget.deviceName,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.crop_free, size: 20),
                color: Colors.white38,
                tooltip: 'Editar overlay',
                onPressed: () => setState(() => _isEditingOverlay = true),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                color: Colors.white38,
                tooltip: 'Volver al joystick',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (_isDemoMode)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber,
                  fontWeight: FontWeight.w500),
            ),
          ),
        const Spacer(),
        DirectionIndicator(x: _currentX, y: _currentY),
        const SizedBox(height: 12),
        Text(
          'X: $_currentX  Y: $_currentY',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'VELOCIDAD',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        SpeedSelector(
          selected: _speedPercent,
          onChanged: (v) {
            setState(() => _speedPercent = v);
            prefsService.speedPercent = v;
            if (_leftValue != 0 || _rightValue != 0) _updateCommand();
          },
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'IZQ: ${(_leftValue * 255 * _speedPercent / 100).round()}',
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white24),
            ),
            const SizedBox(width: 24),
            Text(
              'DER: ${(_rightValue * 255 * _speedPercent / 100).round()}',
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white24),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSideSlider({
    required double value,
    required String label,
    required Color color,
    required ValueChanged<double> onChanged,
    required VoidCallback onReleased,
  }) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          right: BorderSide(color: Color(0xFF2A2A2A)),
          left: BorderSide(color: Color(0xFF2A2A2A)),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 20,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 16),
                  activeTrackColor: color.withValues(alpha: 0.6),
                  inactiveTrackColor: const Color(0xFF252525),
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: value,
                  min: -1.0,
                  max: 1.0,
                  onChanged: onChanged,
                  onChangeEnd: (_) => onReleased(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
