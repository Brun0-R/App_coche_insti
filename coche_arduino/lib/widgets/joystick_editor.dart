import 'package:flutter/material.dart';
import 'joystick_widget.dart';
import 'speed_selector.dart';
import 'connection_indicator.dart';
import 'direction_indicator.dart';

class JoystickConfig {
  Offset position;
  double sizeFactor;

  JoystickConfig({
    this.position = Offset.zero,
    this.sizeFactor = 0.70,
  });

  JoystickConfig copy() => JoystickConfig(
        position: position,
        sizeFactor: sizeFactor,
      );
}

class JoystickEditor extends StatefulWidget {
  final JoystickConfig config;
  final String deviceName;
  final bool isDemoMode;
  final VoidCallback onDone;
  final ValueChanged<JoystickConfig> onChanged;

  const JoystickEditor({
    super.key,
    required this.config,
    required this.deviceName,
    required this.isDemoMode,
    required this.onDone,
    required this.onChanged,
  });

  @override
  State<JoystickEditor> createState() => _JoystickEditorState();
}

class _JoystickEditorState extends State<JoystickEditor> {
  late JoystickConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.config.copy();
  }

  void _onSizeChanged(double v) {
    setState(() => _draft.sizeFactor = v);
    widget.onChanged(_draft);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _draft.position += details.delta);
    widget.onChanged(_draft);
  }

  void _onReset() {
    setState(() {
      _draft.position = Offset.zero;
      _draft.sizeFactor = 0.70;
    });
    widget.onChanged(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;
    final joystickSize = _draft.sizeFactor * screenHeight;

    return Container(
      color: const Color(0xFF121212),
      child: Stack(
        children: [
          // Live preview of the full control screen layout
          Row(
            children: [
              // Left panel preview (dimmed, non-interactive)
              Expanded(
                flex: 2,
                child: Opacity(
                  opacity: 0.4,
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ConnectionIndicator(
                            isConnected: !widget.isDemoMode,
                            deviceName: widget.deviceName,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'MODO',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Joystick', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black)),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'VELOCIDAD',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 10),
                          const SpeedSelector(selected: 50, onChanged: _noOp),
                          const SizedBox(height: 24),
                          const DirectionIndicator(x: 0, y: 0),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: const Text(
                              'X: 0   Y: 0',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.white54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Right panel: draggable joystick preview
              Expanded(
                flex: 3,
                child: Center(
                  child: Transform.translate(
                    offset: _draft.position,
                    child: GestureDetector(
                      onPanUpdate: _onPanUpdate,
                      child: Container(
                        width: joystickSize + 16,
                        height: joystickSize + 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: Center(
                          child: IgnorePointer(
                            child: JoystickWidget(
                              size: joystickSize,
                              onChanged: (_) {},
                              onReleased: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Edit mode banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 14, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'EDITOR — Arrastra el joystick para moverlo',
                    style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_size_select_large, size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  const Text('Tamano', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: accent,
                        inactiveTrackColor: const Color(0xFF2A2A2A),
                        thumbColor: accent,
                        overlayColor: accent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _draft.sizeFactor,
                        min: 0.35,
                        max: 0.95,
                        onChanged: _onSizeChanged,
                      ),
                    ),
                  ),
                  Text(
                    '${(_draft.sizeFactor * 100).round()}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton.icon(
                    onPressed: _onReset,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Restablecer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: widget.onDone,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Listo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _noOp(int v) {}
}
