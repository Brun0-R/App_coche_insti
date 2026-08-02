import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../main.dart' show prefsService;
import '../../models/action_block.dart';
import '../../models/sign.dart';
import '../../services/action_executor.dart';
import '../../services/bluetooth_service.dart';
import '../../services/sign_repository.dart';
import '../../widgets/sign_overlay.dart';
import '../action_editor_screen.dart';

class SignsTab extends StatefulWidget {
  final BluetoothService bluetoothService;
  final SignRepository repository;
  final ActionExecutor executor;

  const SignsTab({
    super.key,
    required this.bluetoothService,
    required this.repository,
    required this.executor,
  });

  @override
  State<SignsTab> createState() => _SignsTabState();
}

class _SignsTabState extends State<SignsTab> {
  late int _trainPhotoCount;

  @override
  void initState() {
    super.initState();
    _trainPhotoCount = prefsService.trainPhotoCount;
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

  void _addSign() {
    final id = widget.repository.nextAvailableId();
    widget.repository.add(Sign(id: id, name: 'Senal $id'));
  }

  void _train(Sign sign) {
    if (!widget.bluetoothService.isConnected) {
      _toast('Conectate al coche para entrenar');
      return;
    }
    widget.bluetoothService.sendTrainCommand(sign.id, _trainPhotoCount);
    _toast('Enviado: $_trainPhotoCount fotos para "${sign.name}"');
  }

  Future<void> _forgetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Olvidar todo lo aprendido?'),
        content: const Text(
          'El HuskyLens borrara su aprendizaje. Las senales de la app se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Olvidar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.bluetoothService.sendForget();
      _toast('Aprendizaje borrado');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final signs = widget.repository.signs;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'signs-add',
        onPressed: _addSign,
        icon: const Icon(Icons.add),
        label: const Text('Senal'),
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderRow(),
            Expanded(
              child: signs.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: signs.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _SignTile(
                        sign: signs[i],
                        onEdit: () => _openEditor(signs[i]),
                        onTrain: () => _train(signs[i]),
                        onDelete: () => widget.repository.remove(signs[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Text(
            'FOTOS POR ENTRENAMIENTO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white38,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: _trainPhotoCount.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              label: '$_trainPhotoCount',
              onChanged: (v) => setState(() => _trainPhotoCount = v.round()),
              onChangeEnd: (v) {
                prefsService.trainPhotoCount = v.round();
              },
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$_trainPhotoCount',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white70,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Olvidar aprendizaje',
            onPressed: _forgetAll,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_search, size: 56, color: Colors.white24),
          SizedBox(height: 12),
          Text('No hay senales aun',
              style: TextStyle(fontSize: 14, color: Colors.white54)),
          SizedBox(height: 4),
          Text('Pulsa "Senal" para anadir la primera',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Future<void> _openEditor(Sign sign) async {
    final draft = sign.copy();
    final result = await Navigator.of(context).push<Sign>(
      MaterialPageRoute(
        builder: (_) => SignEditorScreen(
          sign: draft,
          executor: widget.executor,
        ),
      ),
    );
    if (result != null) {
      widget.repository.update(result);
    }
  }
}

class _SignTile extends StatelessWidget {
  final Sign sign;
  final VoidCallback onEdit;
  final VoidCallback onTrain;
  final VoidCallback onDelete;

  const _SignTile({
    required this.sign,
    required this.onEdit,
    required this.onTrain,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
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
            SignThumb(image: sign.image, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sign.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID ${sign.id}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    describeSequence(sign.sequence),
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTrain,
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              tooltip: 'Entrenar',
              color: Theme.of(context).colorScheme.primary,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Borrar',
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

/// Editor de una senal individual. Publico para poder reusarlo.
class SignEditorScreen extends StatefulWidget {
  final Sign sign;
  final ActionExecutor executor;

  const SignEditorScreen({
    super.key,
    required this.sign,
    required this.executor,
  });

  @override
  State<SignEditorScreen> createState() => _SignEditorScreenState();
}

class _SignEditorScreenState extends State<SignEditorScreen> {
  late TextEditingController _nameController;
  late Sign _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.sign;
    _nameController = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest =
        '${dir.path}/sign_${_draft.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(dest);
    setState(() => _draft.image = SignImage.gallery(dest));
  }

  void _pickPreset() async {
    final selected = await showDialog<IconData>(
      context: context,
      builder: (_) => _PresetIconDialog(current: _draft.image.icon),
    );
    if (selected != null) {
      setState(() => _draft.image = SignImage.preset(selected));
    }
  }

  Future<void> _editActions() async {
    final updated = await Navigator.of(context).push<List<ActionBlock>>(
      MaterialPageRoute(
        builder: (_) => ActionEditorScreen(
          initialSequence: _draft.sequence,
          executor: widget.executor,
          title: _draft.name,
        ),
      ),
    );
    if (updated != null) {
      setState(() => _draft.sequence = updated);
    }
  }

  void _save() {
    _draft.name = _nameController.text.trim().isEmpty
        ? 'Senal ${_draft.id}'
        : _nameController.text.trim();
    Navigator.of(context).pop(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar senal ${_draft.id}',
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('GUARDAR',
                style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: SignThumb(image: _draft.image, size: 96)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Galeria'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPreset,
                    icon: const Icon(Icons.apps, size: 16),
                    label: const Text('Icono'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('NOMBRE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            const Text('ACCIONES (modo automatico)',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _draft.sequence.isEmpty
                        ? 'Sin acciones definidas'
                        : '${_draft.sequence.length} pasos',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _draft.sequence.isEmpty
                        ? 'No hara nada cuando se detecte'
                        : describeSequence(_draft.sequence),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _editActions,
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Editar acciones'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetIconDialog extends StatelessWidget {
  final IconData? current;
  const _PresetIconDialog({this.current});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Elige un icono',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              width: 320,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: PresetIcons.all.map((icon) {
                  final selected = current?.codePoint == icon.codePoint;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(icon),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.2)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? accent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(icon,
                          color: selected ? accent : Colors.white70),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
