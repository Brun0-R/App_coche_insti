import 'package:flutter/material.dart';
import '../../models/action_block.dart';
import '../../models/program.dart';
import '../../services/action_executor.dart';
import '../../services/program_repository.dart';
import '../action_editor_screen.dart';

class ProgramsTab extends StatefulWidget {
  final ProgramRepository repository;
  final ActionExecutor executor;

  const ProgramsTab({
    super.key,
    required this.repository,
    required this.executor,
  });

  @override
  State<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends State<ProgramsTab> {
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

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _addProgram() {
    final n = widget.repository.items.length + 1;
    widget.repository
        .add(Program(id: _newId(), name: 'Programa $n'));
  }

  Future<void> _renameProgram(Program p) async {
    final controller = TextEditingController(text: p.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Renombrar programa'),
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
      p.name = newName;
      widget.repository.update(p);
    }
  }

  Future<void> _editProgram(Program p) async {
    final result = await Navigator.of(context).push<List<ActionBlock>>(
      MaterialPageRoute(
        builder: (_) => ActionEditorScreen(
          initialSequence: p.sequence,
          executor: widget.executor,
          title: p.name,
        ),
      ),
    );
    if (result != null) {
      p.sequence = result;
      widget.repository.update(p);
    }
  }

  void _runProgram(Program p) {
    widget.executor.run(p.sequence);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ejecutando "${p.name}"'),
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
        heroTag: 'programs-add',
        onPressed: _addProgram,
        icon: const Icon(Icons.add),
        label: const Text('Programa'),
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.code_off, size: 56, color: Colors.white24),
                    SizedBox(height: 12),
                    Text('No hay programas',
                        style:
                            TextStyle(fontSize: 14, color: Colors.white54)),
                    SizedBox(height: 4),
                    Text(
                        'Crea uno y asignalo a una senal con el bloque "Ejecutar programa"',
                        textAlign: TextAlign.center,
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
                  final p = items[i];
                  return InkWell(
                    onTap: () => _editProgram(p),
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
                          Icon(Icons.code, color: accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(describeSequence(p.sequence),
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white54)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _runProgram(p),
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Ejecutar',
                            color: accent,
                          ),
                          IconButton(
                            onPressed: () => _renameProgram(p),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Renombrar',
                            color: Colors.white54,
                          ),
                          IconButton(
                            onPressed: () => widget.repository.remove(p.id),
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
