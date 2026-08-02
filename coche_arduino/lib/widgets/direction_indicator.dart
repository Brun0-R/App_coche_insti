import 'dart:math';
import 'package:flutter/material.dart';

class DirectionIndicator extends StatelessWidget {
  final int x;
  final int y;

  const DirectionIndicator({
    super.key,
    required this.x,
    required this.y,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isMoving = x != 0 || y != 0;

    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _DirectionPainter(
          x: x,
          y: y,
          accent: accent,
          isMoving: isMoving,
        ),
      ),
    );
  }
}

class _DirectionPainter extends CustomPainter {
  final int x;
  final int y;
  final Color accent;
  final bool isMoving;

  _DirectionPainter({
    required this.x,
    required this.y,
    required this.accent,
    required this.isMoving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Outer circle
    final bgPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Car body (small rectangle in center)
    const carW = 8.0;
    const carH = 14.0;
    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: carW, height: carH),
      const Radius.circular(2),
    );
    final carPaint = Paint()
      ..color = isMoving ? accent : Colors.white24;
    canvas.drawRRect(carRect, carPaint);

    if (!isMoving) return;

    // Direction arrow
    final normalizedX = x / 255.0;
    final normalizedY = y / 255.0;
    final angle = atan2(-normalizedX, normalizedY); // angle from forward (Y+)
    final magnitude = sqrt(normalizedX * normalizedX + normalizedY * normalizedY);
    final arrowLen = radius * 0.55 * magnitude.clamp(0.3, 1.0);

    final arrowEnd = Offset(
      center.dx + sin(-angle) * arrowLen,
      center.dy - cos(-angle) * arrowLen,
    );

    final arrowPaint = Paint()
      ..color = accent.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, arrowEnd, arrowPaint);

    // Arrowhead
    final headAngle = -angle + pi / 2;
    const headSize = 5.0;
    final path = Path();
    path.moveTo(arrowEnd.dx, arrowEnd.dy);
    path.lineTo(
      arrowEnd.dx - headSize * cos(headAngle - 0.5),
      arrowEnd.dy - headSize * sin(headAngle - 0.5),
    );
    path.moveTo(arrowEnd.dx, arrowEnd.dy);
    path.lineTo(
      arrowEnd.dx - headSize * cos(headAngle + 0.5),
      arrowEnd.dy - headSize * sin(headAngle + 0.5),
    );
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(_DirectionPainter old) => x != old.x || y != old.y;
}
