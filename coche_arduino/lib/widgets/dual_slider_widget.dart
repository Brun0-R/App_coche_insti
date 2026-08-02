import 'package:flutter/material.dart';

class DualSliderWidget extends StatefulWidget {
  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  const DualSliderWidget({
    super.key,
    required this.onChanged,
    required this.onReleased,
  });

  @override
  State<DualSliderWidget> createState() => _DualSliderWidgetState();
}

class _DualSliderWidgetState extends State<DualSliderWidget> {
  double _leftValue = 0;
  double _rightValue = 0;

  void _updateCommand() {
    // Convert tank values to arcade drive (X,Y) for the Arduino
    // Arduino: velLeft = y + x, velRight = y - x
    // Reverse: x = (left - right) / 2, y = (left + right) / 2
    final normalizedX = (_leftValue - _rightValue) / 2;
    final normalizedY = (_leftValue + _rightValue) / 2;
    widget.onChanged(Offset(normalizedX, normalizedY));
  }

  void _onRelease() {
    setState(() {
      _leftValue = 0;
      _rightValue = 0;
    });
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSlider(
            label: 'IZQ',
            value: _leftValue,
            color: accent,
            onChanged: (v) {
              setState(() => _leftValue = v);
              _updateCommand();
            },
            onReleased: _onRelease,
          ),
          const SizedBox(width: 48),
          _buildSlider(
            label: 'DER',
            value: _rightValue,
            color: accent,
            onChanged: (v) {
              setState(() => _rightValue = v);
              _updateCommand();
            },
            onReleased: _onRelease,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    required VoidCallback onReleased,
  }) {
    final displayValue = (value * 255).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$displayValue',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 180,
          child: RotatedBox(
            quarterTurns: 3,
            child: GestureDetector(
              onPanEnd: (_) => onReleased(),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 12,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                  activeTrackColor: color.withValues(alpha: 0.7),
                  inactiveTrackColor: const Color(0xFF2A2A2A),
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.2),
                  trackShape: const RoundedRectSliderTrackShape(),
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
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
