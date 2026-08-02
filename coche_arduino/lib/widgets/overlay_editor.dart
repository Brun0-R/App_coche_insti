import 'package:flutter/material.dart';

/// Editor superpuesto para colocar y escalar el chip del overlay de
/// senal. Reusa visualmente el mismo chip pero con la imagen/icono de
/// muestra; los cambios se guardan al pulsar "Listo".
class OverlayEditor extends StatefulWidget {
  final Offset initialPositionFrac;
  final double initialScale;
  final void Function(Offset positionFrac, double scale) onDone;
  final VoidCallback onCancel;

  const OverlayEditor({
    super.key,
    required this.initialPositionFrac,
    required this.initialScale,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<OverlayEditor> createState() => _OverlayEditorState();
}

class _OverlayEditorState extends State<OverlayEditor> {
  late Offset _frac;
  late double _scale;

  @override
  void initState() {
    super.initState();
    _frac = widget.initialPositionFrac;
    _scale = widget.initialScale;
  }

  void _reset() {
    setState(() {
      _frac = const Offset(0.78, 0.04);
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      color: const Color(0xE6121212),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              // Chip arrastrable (con muestra) — recibe el gesto en
              // la propia caja del chip.
              Positioned(
                left: (w * _frac.dx).clamp(0.0, w - 30),
                top: (h * _frac.dy).clamp(0.0, h - 30),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {},
                  onPanUpdate: (d) {
                    setState(() {
                      _frac = Offset(
                        (_frac.dx + d.delta.dx / w).clamp(0.0, 0.95),
                        (_frac.dy + d.delta.dy / h).clamp(0.0, 0.95),
                      );
                    });
                  },
                  child: _buildSampleChip(accent),
                ),
              ),

              // Banner arriba
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                border: Border(
                    bottom:
                        BorderSide(color: accent.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 14, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'EDITOR DE OVERLAY — Arrastra el chip para colocarlo',
                    style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white54,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),

          // Controles abajo
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_size_select_large,
                      size: 16, color: Colors.white38),
                  const SizedBox(width: 8),
                  const Text('Tamano',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: accent,
                        inactiveTrackColor: const Color(0xFF2A2A2A),
                        thumbColor: accent,
                        overlayColor: accent.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _scale,
                        min: 0.5,
                        max: 2.5,
                        onChanged: (v) => setState(() => _scale = v),
                      ),
                    ),
                  ),
                  Text(
                    '${(_scale * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Restablecer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => widget.onDone(_frac, _scale),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Listo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSampleChip(Color accent) {
    final s = _scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: const Color(0xCC1E1E1E),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32 * s,
            height: 32 * s,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.stop, size: 20 * s, color: accent),
          ),
          SizedBox(width: 8 * s),
          Text(
            'Senal de muestra',
            style: TextStyle(
                fontSize: 12 * s,
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Pequeno helper para colocar el [SignOverlay] en su posicion
/// configurada dentro de un Stack.
Positioned positionedOverlay({
  required Offset positionFrac,
  required Widget child,
  required Size screenSize,
}) {
  return Positioned(
    left: screenSize.width * positionFrac.dx,
    top: screenSize.height * positionFrac.dy,
    child: child,
  );
}

// Default constants for the overlay placement.
const Offset kDefaultOverlayFrac = Offset(0.78, 0.04);
const double kDefaultOverlayScale = 1.0;
