import 'package:flutter/material.dart';

class SpeedSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  static const List<int> options = [25, 50, 75, 100];

  const SpeedSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((value) {
        final isSelected = value == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? accent : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? accent
                      : const Color(0xFF3A3A3A),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$value%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
