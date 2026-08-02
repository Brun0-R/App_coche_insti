import 'dart:math';
import 'package:flutter/material.dart';

class JoystickWidget extends StatefulWidget {
  final double size;
  final double deadZone;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  const JoystickWidget({
    super.key,
    required this.size,
    this.deadZone = 0.10,
    required this.onChanged,
    required this.onReleased,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget>
    with SingleTickerProviderStateMixin {
  Offset _thumbPosition = Offset.zero;
  late AnimationController _animController;
  late Animation<Offset> _animation;

  double get _radius => widget.size / 2;
  double get _thumbRadius => widget.size * 0.18;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.addListener(() {
      setState(() => _thumbPosition = _animation.value);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _animController.stop();

    final center = Offset(_radius, _radius);
    final localPosition = details.localPosition;
    final delta = localPosition - center;
    final distance = delta.distance;
    final maxDistance = _radius - _thumbRadius;

    Offset clamped;
    if (distance > maxDistance) {
      clamped = Offset(
        delta.dx / distance * maxDistance,
        delta.dy / distance * maxDistance,
      );
    } else {
      clamped = delta;
    }

    setState(() => _thumbPosition = clamped);

    final normalizedX = clamped.dx / maxDistance;
    final normalizedY = -clamped.dy / maxDistance; // Invert Y: up = positive
    final normalizedDistance = min(distance, maxDistance) / maxDistance;

    if (normalizedDistance < widget.deadZone) {
      widget.onChanged(Offset.zero);
    } else {
      widget.onChanged(Offset(normalizedX, normalizedY));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _animation = Tween<Offset>(
      begin: _thumbPosition,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward(from: 0);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: CustomPaint(
          painter: _JoystickPainter(
            thumbPosition: _thumbPosition,
            baseRadius: _radius,
            thumbRadius: _thumbRadius,
            accentColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset thumbPosition;
  final double baseRadius;
  final double thumbRadius;
  final Color accentColor;

  _JoystickPainter({
    required this.thumbPosition,
    required this.baseRadius,
    required this.thumbRadius,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring
    final outerPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius, outerPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, baseRadius, borderPaint);

    // Cross lines (subtle guides)
    final guidePaint = Paint()
      ..color = const Color(0xFF252525)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx, center.dy - baseRadius + 20),
      Offset(center.dx, center.dy + baseRadius - 20),
      guidePaint,
    );
    canvas.drawLine(
      Offset(center.dx - baseRadius + 20, center.dy),
      Offset(center.dx + baseRadius - 20, center.dy),
      guidePaint,
    );

    // Thumb shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      center + thumbPosition + const Offset(2, 2),
      thumbRadius,
      shadowPaint,
    );

    // Thumb gradient
    final thumbCenter = center + thumbPosition;
    final thumbGradient = RadialGradient(
      colors: [
        accentColor.withValues(alpha: 0.9),
        accentColor.withValues(alpha: 0.6),
      ],
    );
    final thumbPaint = Paint()
      ..shader = thumbGradient.createShader(
        Rect.fromCircle(center: thumbCenter, radius: thumbRadius),
      );
    canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);

    // Thumb border
    final thumbBorderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(thumbCenter, thumbRadius, thumbBorderPaint);
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) {
    return thumbPosition != oldDelegate.thumbPosition;
  }
}
