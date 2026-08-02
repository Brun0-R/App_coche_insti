import 'package:flutter/material.dart';

class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  final String deviceName;

  const ConnectionIndicator({
    super.key,
    required this.isConnected,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
            boxShadow: [
              BoxShadow(
                color: (isConnected ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))
                    .withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isConnected ? deviceName : 'Desconectado',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isConnected ? Colors.white70 : Colors.white38,
          ),
        ),
      ],
    );
  }
}
