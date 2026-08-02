import 'package:flutter/material.dart';
import '../../models/action_block.dart';
import '../../models/macro.dart';
import '../../services/action_executor.dart';
import '../../services/bluetooth_service.dart';
import '../../services/macro_repository.dart';
import '../macro_recorder_screen.dart';

class MacrosTab extends StatefulWidget {
  final BluetoothService bluetoothService;
  final MacroRepository repository;
  final ActionExecutor executor;

  const MacrosTab({
    super.key,
    required this.bluetoothService,
    required this.repository,
    required this.executor,
  });

  @override
  State<MacrosTab> createState() => _MacrosTabState();
}

class _MacrosTabState extends State<MacrosTab> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _newRecording() async {
    final result = await Navigator.of(context).push<Macro>(
      MaterialPageRoute(
        builder: (_) => MacroRecorderScreen(
          bluetoothService: widget.bluetoothService,
          existing: null,
        ),
      ),
    );
    if (result != null) widget.repository.add(result);
  }

  Future<void> _renameMacro(Macro m) async {
    final controller = TextEditingController(text: m.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Renombrar macro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      m.name = newName;
      widget.repository.update(m);
    }
  }

  void _playMacro(Macro m) {
    if (m.samples.isEmpty) return;
    widget.executor.run([RunMacroBlock(macroId: m.id)]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reproduciendo "${m.name}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final items = widget.repository.items;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'macros-add',
        onPressed: _newRecording,
        icon: const Icon(Icons.fiber_manual_record),
        label: const Text('Grabar'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.fiber_manual_record_outlined,
                        size: 56, color: Colors.white24),
                    SizedBox(height: 12),
                    Text('No hay macros',
                        style:
                            TextStyle(fontSize: 14, color: Colors.white54)),
                    SizedBox(height: 4),
                    Text('Pulsa "Grabar" para grabar tu primer circuito',
                        style:
                            TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              )
            : ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: items.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = items[i];
                  return InkWell(
                    onTap: () => _renameMacro(m),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record,
                              color: Colors.redAccent.withValues(alpha: 0.7)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  '${m.samples.length} puntos · ${(m.durationMs / 1000).toStringAsFixed(1)}s',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _playMacro(m),
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Reproducir',
                            color: accent,
                          ),
                          IconButton(
                            onPressed: () => widget.repository.remove(m.id),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Borrar',
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

