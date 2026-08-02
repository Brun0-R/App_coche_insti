import 'package:flutter/material.dart';
import '../main.dart' show macroRepository, programRepository;
import '../models/action_block.dart';
import '../services/action_executor.dart';

class ActionEditorScreen extends StatefulWidget {
  final List<ActionBlock> initialSequence;
  final ActionExecutor executor;
  final String title;

  /// Si es true, se renderiza sin AppBar (para incrustar en otra pantalla).
  final bool embedded;

  /// Se invoca al pulsar "Guardar". Si es null, hace pop con la lista.
  final void Function(List<ActionBlock>)? onSave;

  const ActionEditorScreen({
    super.key,
    required this.initialSequence,
    required this.executor,
    required this.title,
    this.embedded = false,
    this.onSave,
  });

  @override
  State<ActionEditorScreen> createState() => _ActionEditorScreenState();
}

class _ActionEditorScreenState extends State<ActionEditorScreen> {
  late List<ActionBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = widget.initialSequence.map((b) => b.copy()).toList();
  }

  @override
  void dispose() {
    widget.executor.cancel();
    super.dispose();
  }

  Future<void> _addBlock([List<ActionBlock>? parent]) async {
    final target = parent ?? _blocks;
    final newBlock = await showModalBottomSheet<ActionBlock>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (_) => const _AddBlockSheet(),
    );
    if (newBlock != null) {
      setState(() => target.add(newBlock));
    }
  }

  void _removeAt(List<ActionBlock> list, int index) {
    setState(() => list.removeAt(index));
  }

  void _reorder(List<ActionBlock> list, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  void _save() {
    if (widget.onSave != null) {
      widget.onSave!(_blocks);
    } else {
      Navigator.of(context).pop(_blocks);
    }
  }

  void _test() {
    widget.executor.run(_blocks);
  }

  void _stop() {
    widget.executor.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text('Acciones - ${widget.title}',
                  style: const TextStyle(fontSize: 14)),
              actions: [
                ValueListenableBuilder<ExecutionState>(
                  valueListenable: widget.executor,
                  builder: (context, state, _) => state.running
                      ? IconButton(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop_circle,
                              color: Colors.redAccent),
                          tooltip: 'Parar',
                        )
                      : IconButton(
                          onPressed: _blocks.isEmpty ? null : _test,
                          icon: const Icon(Icons.play_arrow),
                          color: accent,
                          tooltip: 'Probar',
                        ),
                ),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'action-editor-add',
        onPressed: () => _addBlock(),
        icon: const Icon(Icons.add),
        label: const Text('Bloque'),
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<ExecutionState>(
              valueListenable: widget.executor,
              builder: (context, state, _) => state.running
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: accent.withValues(alpha: 0.15),
                      child: Text(
                        'EJECUTANDO ${state.currentIndex + 1}/${state.totalBlocks}: ${state.currentBlock != null ? describeBlock(state.currentBlock!) : "..."}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _blocks.isEmpty
                  ? _buildEmpty()
                  : _buildList(_blocks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.play_circle_outline, size: 56, color: Colors.white24),
          SizedBox(height: 12),
          Text('Sin bloques',
              style: TextStyle(fontSize: 14, color: Colors.white54)),
          SizedBox(height: 4),
          Text('Pulsa "Bloque" para anadir el primero',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildList(List<ActionBlock> list) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: list.length,
      onReorder: (oldI, newI) => _reorder(list, oldI, newI),
      proxyDecorator: (child, index, anim) => Material(
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (_, index) {
        final item = list[index];
        VoidCallback? addChild;
        VoidCallback? addIfThen;
        VoidCallback? addIfElse;
        if (item is RepeatBlock) {
          addChild = () => _addBlock(item.children);
        } else if (item is WhileForeverBlock) {
          addChild = () => _addBlock(item.children);
        } else if (item is RandomBlock) {
          addChild = () => _addBlock(item.children);
        } else if (item is IfSignBlock) {
          addIfThen = () => _addBlock(item.thenChildren);
          addIfElse = () => _addBlock(item.elseChildren);
        } else if (item is IfVarBlock) {
          addIfThen = () => _addBlock(item.thenChildren);
          addIfElse = () => _addBlock(item.elseChildren);
        }
        return Padding(
          key: ValueKey(item),
          padding: const EdgeInsets.only(bottom: 8),
          child: _BlockCard(
            block: item,
            index: index,
            onChanged: (updated) => setState(() => list[index] = updated),
            onRemove: () => _removeAt(list, index),
            onAddChild: addChild,
            onAddIfThen: addIfThen,
            onAddIfElse: addIfElse,
          ),
        );
      },
    );
  }
}

class _AddBlockSheet extends StatelessWidget {
  const _AddBlockSheet();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final entries = <_AddOption>[
      _AddOption(
        icon: Icons.directions_car,
        label: 'Movimiento',
        sub: 'Avanzar, frenar, girar...',
        build: () => MoveBlock(kind: MoveKind.forward, durationMs: 500),
      ),
      _AddOption(
        icon: Icons.tune,
        label: 'Motor crudo',
        sub: 'X/Y o IZQ/DER directos',
        build: () =>
            RawMotorBlock(mode: RawMode.xy, a: 0, b: 200, durationMs: 500),
      ),
      _AddOption(
        icon: Icons.timer_outlined,
        label: 'Esperar',
        sub: 'Pausa de N ms',
        build: () => DelayBlock(ms: 500),
      ),
      _AddOption(
        icon: Icons.speed,
        label: 'Velocidad',
        sub: 'Cambiar % de los siguientes',
        build: () => SpeedBlock(percent: 80),
      ),
      _AddOption(
        icon: Icons.repeat,
        label: 'Repetir',
        sub: 'Bucle con N veces',
        build: () => RepeatBlock(times: 2, children: []),
      ),
      _AddOption(
        icon: Icons.all_inclusive,
        label: 'Bucle infinito',
        sub: 'while(true): hasta que pare',
        build: () => WhileForeverBlock(children: []),
      ),
      _AddOption(
        icon: Icons.shuffle,
        label: 'Aleatorio',
        sub: 'Elige un hijo al azar',
        build: () => RandomBlock(children: []),
      ),
      _AddOption(
        icon: Icons.alt_route,
        label: 'Si veo senal',
        sub: 'If/else basado en la ultima senal',
        build: () =>
            IfSignBlock(signId: 0, thenChildren: [], elseChildren: []),
      ),
      _AddOption(
        icon: Icons.hourglass_top,
        label: 'Esperar senal',
        sub: 'Pausa hasta ver una senal',
        build: () => WaitForSignBlock(signId: 0),
      ),
      _AddOption(
        icon: Icons.casino_outlined,
        label: 'Esperar aleatorio',
        sub: 'Pausa entre min-max ms',
        build: () => RandomDelayBlock(minMs: 200, maxMs: 1000),
      ),
      _AddOption(
        icon: Icons.tag,
        label: 'Asignar variable',
        sub: 'X = N. Si nombre empieza por \$, es global',
        build: () => SetVarBlock(name: 'x', value: 0),
      ),
      _AddOption(
        icon: Icons.exposure,
        label: 'Sumar a variable',
        sub: 'X += N (puede ser negativo)',
        build: () => ChangeVarBlock(name: 'x', delta: 1),
      ),
      _AddOption(
        icon: Icons.rule,
        label: 'Si variable',
        sub: 'If X (== < > ...) N then/else',
        build: () => IfVarBlock(
            name: 'x', op: CompareOp.eq, value: 0,
            thenChildren: [], elseChildren: []),
      ),
      _AddOption(
        icon: Icons.code,
        label: 'Ejecutar programa',
        sub: 'Llama a un programa guardado',
        build: () => RunProgramBlock(programId: ''),
      ),
      _AddOption(
        icon: Icons.fiber_manual_record,
        label: 'Reproducir macro',
        sub: 'Reproduce una macro grabada',
        build: () => RunMacroBlock(macroId: ''),
      ),
      _AddOption(
        icon: Icons.stop,
        label: 'Parar todo',
        sub: 'Corta la secuencia',
        build: () => StopAllBlock(),
      ),
    ];

    final maxH = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('NUEVO BLOQUE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white54)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: entries
                      .map((e) => ListTile(
                            leading: Icon(e.icon, color: accent),
                            title: Text(e.label,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(e.sub,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white54)),
                            onTap: () => Navigator.of(context).pop(e.build()),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOption {
  final IconData icon;
  final String label;
  final String sub;
  final ActionBlock Function() build;
  const _AddOption({
    required this.icon,
    required this.label,
    required this.sub,
    required this.build,
  });
}

class _BlockCard extends StatelessWidget {
  final ActionBlock block;
  final int index;
  final ValueChanged<ActionBlock> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onAddChild;
  final VoidCallback? onAddIfThen;
  final VoidCallback? onAddIfElse;

  const _BlockCard({
    required this.block,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    this.onAddChild,
    this.onAddIfThen,
    this.onAddIfElse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator,
                      size: 18, color: Colors.white24),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _blockTitle(block),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.white38,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildEditor(block, onChanged),
          ),
          ..._buildChildLists(context),
        ],
      ),
    );
  }

  List<Widget> _buildChildLists(BuildContext context) {
    final b = block;
    if (b is RepeatBlock) {
      return [
        _buildChildBox(context,
            title: 'CONTENIDO',
            children: b.children,
            onChange: () => onChanged(b),
            onAdd: onAddChild)
      ];
    }
    if (b is WhileForeverBlock) {
      return [
        _buildChildBox(context,
            title: 'CONTENIDO',
            children: b.children,
            onChange: () => onChanged(b),
            onAdd: onAddChild)
      ];
    }
    if (b is RandomBlock) {
      return [
        _buildChildBox(context,
            title: 'OPCIONES',
            children: b.children,
            onChange: () => onChanged(b),
            onAdd: onAddChild)
      ];
    }
    if (b is IfSignBlock) {
      return [
        _buildChildBox(context,
            title: 'ENTONCES',
            children: b.thenChildren,
            onChange: () => onChanged(b),
            onAdd: onAddIfThen),
        _buildChildBox(context,
            title: 'SI NO (opcional)',
            children: b.elseChildren,
            onChange: () => onChanged(b),
            onAdd: onAddIfElse),
      ];
    }
    if (b is IfVarBlock) {
      return [
        _buildChildBox(context,
            title: 'ENTONCES',
            children: b.thenChildren,
            onChange: () => onChanged(b),
            onAdd: onAddIfThen),
        _buildChildBox(context,
            title: 'SI NO (opcional)',
            children: b.elseChildren,
            onChange: () => onChanged(b),
            onAdd: onAddIfElse),
      ];
    }
    return const [];
  }
  // Eliminado: _buildRepeatChildren reemplazado por _buildChildBox.

  Widget _buildChildBox(BuildContext context,
      {required String title,
      required List<ActionBlock> children,
      required VoidCallback onChange,
      required VoidCallback? onAdd}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${children.length})',
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white38,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 6),
          if (children.isEmpty)
            const Text('Vacio',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
          ...children.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.key + 1}. ${describeBlock(e.value)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          children.removeAt(e.key);
                          onChange();
                        },
                        icon: const Icon(Icons.close, size: 14),
                        visualDensity: VisualDensity.compact,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Bloque dentro',
                  style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  String _blockTitle(ActionBlock b) {
    return switch (b) {
      MoveBlock() => 'MOVIMIENTO',
      RawMotorBlock() => 'MOTOR CRUDO',
      DelayBlock() => 'ESPERAR',
      RandomDelayBlock() => 'ESPERAR ALEATORIO',
      SpeedBlock() => 'VELOCIDAD',
      RepeatBlock() => 'REPETIR',
      WhileForeverBlock() => 'BUCLE INFINITO',
      IfSignBlock() => 'SI VEO SENAL',
      WaitForSignBlock() => 'ESPERAR SENAL',
      RandomBlock() => 'ALEATORIO',
      SetVarBlock() => 'ASIGNAR VAR',
      ChangeVarBlock() => 'SUMAR A VAR',
      IfVarBlock() => 'SI VARIABLE',
      RunProgramBlock() => 'EJECUTAR PROGRAMA',
      RunMacroBlock() => 'REPRODUCIR MACRO',
      StopAllBlock() => 'PARAR TODO',
    };
  }

  Widget _buildEditor(ActionBlock b, ValueChanged<ActionBlock> onChanged) {
    return switch (b) {
      MoveBlock() => _MoveEditor(block: b, onChanged: onChanged),
      RawMotorBlock() => _RawEditor(block: b, onChanged: onChanged),
      DelayBlock() => _DelayEditor(block: b, onChanged: onChanged),
      RandomDelayBlock() =>
        _RandomDelayEditor(block: b, onChanged: onChanged),
      SpeedBlock() => _SpeedEditor(block: b, onChanged: onChanged),
      RepeatBlock() => _RepeatEditor(block: b, onChanged: onChanged),
      WhileForeverBlock() => const Text(
          'Repite los bloques internos sin parar (until cancelacion).',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      IfSignBlock() => _IfSignEditor(block: b, onChanged: onChanged),
      WaitForSignBlock() =>
        _WaitForSignEditor(block: b, onChanged: onChanged),
      RandomBlock() => const Text(
          'Cada vez que se ejecute, elige uno de los bloques de dentro.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      SetVarBlock() => _SetVarEditor(block: b, onChanged: onChanged),
      ChangeVarBlock() => _ChangeVarEditor(block: b, onChanged: onChanged),
      IfVarBlock() => _IfVarEditor(block: b, onChanged: onChanged),
      RunProgramBlock() =>
        _RunProgramEditor(block: b, onChanged: onChanged),
      RunMacroBlock() => _RunMacroEditor(block: b, onChanged: onChanged),
      StopAllBlock() => const Text(
          'Cancela cualquier accion en curso y para los motores.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
    };
  }

}

class _MoveEditor extends StatelessWidget {
  final MoveBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _MoveEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<MoveKind>(
          value: block.kind,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          underline: const SizedBox.shrink(),
          items: MoveKind.values
              .map((k) => DropdownMenuItem(
                    value: k,
                    child: Row(
                      children: [
                        Icon(k.icon, size: 16, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(k.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (k) {
            if (k != null) {
              block.kind = k;
              onChanged(block);
            }
          },
        ),
        const SizedBox(height: 6),
        _DurationField(
          value: block.durationMs,
          onChanged: (ms) {
            block.durationMs = ms;
            onChanged(block);
          },
        ),
      ],
    );
  }
}

class _RawEditor extends StatelessWidget {
  final RawMotorBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _RawEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<RawMode>(
          segments: const [
            ButtonSegment(value: RawMode.xy, label: Text('X/Y arcade')),
            ButtonSegment(value: RawMode.tank, label: Text('IZQ/DER')),
          ],
          selected: {block.mode},
          onSelectionChanged: (s) {
            block.mode = s.first;
            onChanged(block);
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                label: block.mode == RawMode.xy ? 'X' : 'IZQ',
                value: block.a,
                min: -255,
                max: 255,
                onChanged: (v) {
                  block.a = v;
                  onChanged(block);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                label: block.mode == RawMode.xy ? 'Y' : 'DER',
                value: block.b,
                min: -255,
                max: 255,
                onChanged: (v) {
                  block.b = v;
                  onChanged(block);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _DurationField(
          value: block.durationMs,
          onChanged: (ms) {
            block.durationMs = ms;
            onChanged(block);
          },
        ),
      ],
    );
  }
}

class _DelayEditor extends StatelessWidget {
  final DelayBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _DelayEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _NumberField(
      label: 'ms',
      value: block.ms,
      min: 0,
      max: 60000,
      onChanged: (v) {
        block.ms = v;
        onChanged(block);
      },
    );
  }
}

class _SpeedEditor extends StatelessWidget {
  final SpeedBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _SpeedEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: block.percent.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '${block.percent}%',
            onChanged: (v) {
              block.percent = v.round();
              onChanged(block);
            },
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${block.percent}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _RepeatEditor extends StatelessWidget {
  final RepeatBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _RepeatEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Veces',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: _NumberField(
            label: '',
            value: block.times,
            min: 1,
            max: 50,
            onChanged: (v) {
              block.times = v;
              onChanged(block);
            },
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _NumberField old) {
    super.didUpdateWidget(old);
    if (widget.value.toString() != _controller.text) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label.isEmpty ? null : widget.label,
        labelStyle: const TextStyle(fontSize: 11, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF101010),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) {
          final clamped = parsed.clamp(widget.min, widget.max);
          widget.onChanged(clamped);
        }
      },
    );
  }
}

class _DurationField extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _DurationField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasDuration = value != null;
    return Row(
      children: [
        Switch(
          value: hasDuration,
          onChanged: (v) => onChanged(v ? 500 : null),
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        const Text('Duracion',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(width: 8),
        if (hasDuration)
          Expanded(
            child: _NumberField(
              label: 'ms',
              value: value!,
              min: 0,
              max: 60000,
              onChanged: (v) => onChanged(v),
            ),
          )
        else
          const Expanded(
            child: Text(
              'sin limite (hasta el siguiente bloque o stop)',
              style: TextStyle(fontSize: 11, color: Colors.white38),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _RandomDelayEditor extends StatelessWidget {
  final RandomDelayBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _RandomDelayEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NumberField(
            label: 'min ms',
            value: block.minMs,
            min: 0,
            max: 60000,
            onChanged: (v) {
              block.minMs = v;
              onChanged(block);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NumberField(
            label: 'max ms',
            value: block.maxMs,
            min: 0,
            max: 60000,
            onChanged: (v) {
              block.maxMs = v;
              onChanged(block);
            },
          ),
        ),
      ],
    );
  }
}

class _IfSignEditor extends StatelessWidget {
  final IfSignBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _IfSignEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Senal id (0 = cualquiera)',
            style: TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: _NumberField(
            label: '',
            value: block.signId,
            min: 0,
            max: 50,
            onChanged: (v) {
              block.signId = v;
              onChanged(block);
            },
          ),
        ),
      ],
    );
  }
}

class _WaitForSignEditor extends StatelessWidget {
  final WaitForSignBlock block;
  final ValueChanged<ActionBlock> onChanged;

  const _WaitForSignEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasTimeout = block.timeoutMs != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Senal id (0 = cualquiera)',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: _NumberField(
                label: '',
                value: block.signId,
                min: 0,
                max: 50,
                onChanged: (v) {
                  block.signId = v;
                  onChanged(block);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Switch(
              value: hasTimeout,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) {
                block.timeoutMs = v ? 5000 : null;
                onChanged(block);
              },
            ),
            const SizedBox(width: 4),
            const Text('Timeout',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(width: 8),
            if (hasTimeout)
              Expanded(
                child: _NumberField(
                  label: 'ms',
                  value: block.timeoutMs!,
                  min: 0,
                  max: 60000,
                  onChanged: (v) {
                    block.timeoutMs = v;
                    onChanged(block);
                  },
                ),
              )
            else
              const Expanded(
                child: Text(
                  'sin limite (espera para siempre)',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SetVarEditor extends StatelessWidget {
  final SetVarBlock block;
  final ValueChanged<ActionBlock> onChanged;
  const _SetVarEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NameField(
            value: block.name,
            onChanged: (v) {
              block.name = v;
              onChanged(block);
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text('=',
            style: TextStyle(fontSize: 16, color: Colors.white54)),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: _NumberField(
            label: 'valor',
            value: block.value,
            min: -1000000,
            max: 1000000,
            onChanged: (v) {
              block.value = v;
              onChanged(block);
            },
          ),
        ),
      ],
    );
  }
}

class _ChangeVarEditor extends StatelessWidget {
  final ChangeVarBlock block;
  final ValueChanged<ActionBlock> onChanged;
  const _ChangeVarEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NameField(
            value: block.name,
            onChanged: (v) {
              block.name = v;
              onChanged(block);
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text('+=',
            style: TextStyle(fontSize: 14, color: Colors.white54)),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: _NumberField(
            label: 'delta',
            value: block.delta,
            min: -1000000,
            max: 1000000,
            onChanged: (v) {
              block.delta = v;
              onChanged(block);
            },
          ),
        ),
      ],
    );
  }
}

class _IfVarEditor extends StatelessWidget {
  final IfVarBlock block;
  final ValueChanged<ActionBlock> onChanged;
  const _IfVarEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NameField(
            value: block.name,
            onChanged: (v) {
              block.name = v;
              onChanged(block);
            },
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<CompareOp>(
          value: block.op,
          dropdownColor: const Color(0xFF1A1A1A),
          underline: const SizedBox.shrink(),
          items: CompareOp.values
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.symbol,
                        style: const TextStyle(fontFamily: 'monospace')),
                  ))
              .toList(),
          onChanged: (op) {
            if (op != null) {
              block.op = op;
              onChanged(block);
            }
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: _NumberField(
            label: 'valor',
            value: block.value,
            min: -1000000,
            max: 1000000,
            onChanged: (v) {
              block.value = v;
              onChanged(block);
            },
          ),
        ),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _NameField({required this.value, required this.onChanged});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: 'variable (\$ = global)',
        labelStyle: const TextStyle(fontSize: 11, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF101010),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _RunProgramEditor extends StatelessWidget {
  final RunProgramBlock block;
  final ValueChanged<ActionBlock> onChanged;
  const _RunProgramEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final programs = programRepository.items;
    if (programs.isEmpty) {
      return const Text(
        'No hay programas guardados. Crea uno en Biblioteca > Programas.',
        style: TextStyle(fontSize: 11, color: Colors.white54),
      );
    }
    final exists = programs.any((p) => p.id == block.programId);
    final value = exists ? block.programId : programs.first.id;
    if (!exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        block.programId = value;
        onChanged(block);
      });
    }
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF1A1A1A),
      underline: const SizedBox.shrink(),
      items: programs
          .map((p) => DropdownMenuItem(
                value: p.id,
                child: Text(p.name,
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (id) {
        if (id != null) {
          block.programId = id;
          onChanged(block);
        }
      },
    );
  }
}

class _RunMacroEditor extends StatelessWidget {
  final RunMacroBlock block;
  final ValueChanged<ActionBlock> onChanged;
  const _RunMacroEditor({required this.block, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final macros = macroRepository.items;
    if (macros.isEmpty) {
      return const Text(
        'No hay macros grabadas. Graba una en Biblioteca > Macros.',
        style: TextStyle(fontSize: 11, color: Colors.white54),
      );
    }
    final exists = macros.any((m) => m.id == block.macroId);
    final value = exists ? block.macroId : macros.first.id;
    if (!exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        block.macroId = value;
        onChanged(block);
      });
    }
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF1A1A1A),
      underline: const SizedBox.shrink(),
      items: macros
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text(
                  '${m.name} (${(m.durationMs / 1000).toStringAsFixed(1)}s)',
                  style: const TextStyle(fontSize: 13),
                ),
              ))
          .toList(),
      onChanged: (id) {
        if (id != null) {
          block.macroId = id;
          onChanged(block);
        }
      },
    );
  }
}
