import 'package:flutter/material.dart';
import '../../models/husky_algorithm.dart';
import '../../services/bluetooth_service.dart';
import '../../services/preferences_service.dart';

class AlgorithmsTab extends StatefulWidget {
  final BluetoothService bluetoothService;
  final PreferencesService prefsService;

  const AlgorithmsTab({
    super.key,
    required this.bluetoothService,
    required this.prefsService,
  });

  @override
  State<AlgorithmsTab> createState() => _AlgorithmsTabState();
}

class _AlgorithmsTabState extends State<AlgorithmsTab> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.prefsService.huskyAlgorithm;
  }

  void _select(HuskyAlgorithm algo) {
    setState(() => _selected = algo.code);
    widget.prefsService.huskyAlgorithm = algo.code;
    if (widget.bluetoothService.isConnected) {
      widget.bluetoothService.sendAlgorithm(algo.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Algoritmo: ${algo.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Algoritmo guardado (${algo.name}). Se aplicara al conectar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: accent, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'El algoritmo cambia que detecta el HuskyLens. La app trata todas las detecciones igual: las identifica por ID y las puedes asignar a senales.',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...HuskyAlgorithm.all.map((algo) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _select(algo),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selected == algo.code
                          ? accent.withValues(alpha: 0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selected == algo.code
                            ? accent
                            : const Color(0xFF2A2A2A),
                        width: _selected == algo.code ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(algo.icon,
                              color: _selected == algo.code
                                  ? accent
                                  : Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                algo.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _selected == algo.code
                                      ? accent
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                algo.description,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        if (_selected == algo.code)
                          Icon(Icons.check_circle, color: accent),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
