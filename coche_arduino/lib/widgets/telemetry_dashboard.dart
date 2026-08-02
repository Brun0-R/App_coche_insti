import 'dart:io';
import 'package:flutter/material.dart';
import '../models/sign.dart';
import '../models/telemetry_config.dart';
import '../services/action_executor.dart';
import '../services/bluetooth_service.dart';
import '../services/variable_store.dart';
import 'direction_indicator.dart';
import 'sign_overlay.dart';

/// Dashboard configurable: cada item se posiciona libremente.
/// En modo edicion ([editing]), los items son arrastrables y aparece
/// un boton de visibilidad y un slider de tamano por encima del activo.
class TelemetryDashboard extends StatelessWidget {
  final TelemetryConfig config;
  final ExecutionState state;
  final Sign? activeSign;
  final BluetoothService bluetoothService;
  final VariableStore variables;
  final bool editing;
  final TelemetryItem? selected;
  final void Function(TelemetryItem item, Offset newFrac)? onMove;
  final void Function(TelemetryItem item)? onTap;

  const TelemetryDashboard({
    super.key,
    required this.config,
    required this.state,
    required this.activeSign,
    required this.bluetoothService,
    required this.variables,
    this.editing = false,
    this.selected,
    this.onMove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: config.items
              .where((item) => editing || item.visible)
              .map((item) {
            final isSelected = item == selected;
            final left = (size.width * item.positionFrac.dx)
                .clamp(0.0, size.width - 30);
            final top = (size.height * item.positionFrac.dy)
                .clamp(0.0, size.height - 30);
            final widget = Opacity(
              opacity: editing && !item.visible ? 0.4 : 1.0,
              child: _buildItem(context, item),
            );
            if (!editing) {
              return Positioned(left: left, top: top, child: widget);
            }
            return Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap?.call(item),
                onPanUpdate: (d) {
                  final newX = (item.positionFrac.dx + d.delta.dx / size.width)
                      .clamp(0.0, 0.95);
                  final newY = (item.positionFrac.dy + d.delta.dy / size.height)
                      .clamp(0.0, 0.95);
                  onMove?.call(item, Offset(newX, newY));
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: widget,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, TelemetryItem item) {
    switch (item.kind) {
      case TelemetryKind.signCard:
        return _SignCard(sign: activeSign, scale: item.scale);
      case TelemetryKind.currentBlock:
        return _CurrentBlock(state: state, scale: item.scale);
      case TelemetryKind.direction:
        return Transform.scale(
          scale: item.scale,
          child: DirectionIndicator(x: state.currentX, y: state.currentY),
        );
      case TelemetryKind.xy:
        return _telemetryBox(
          scale: item.scale,
          children: [
            _row('X', state.currentX.toString()),
            _row('Y', state.currentY.toString()),
          ],
        );
      case TelemetryKind.leftMotor:
        final accent = Theme.of(context).colorScheme.primary;
        return _telemetryBox(
          scale: item.scale,
          children: [
            _row('IZQ', state.leftMotor.toString(), color: accent),
            const SizedBox(height: 4),
            _bar(state.leftMotor, accent),
          ],
        );
      case TelemetryKind.rightMotor:
        final accent = Theme.of(context).colorScheme.primary;
        return _telemetryBox(
          scale: item.scale,
          children: [
            _row('DER', state.rightMotor.toString(), color: accent),
            const SizedBox(height: 4),
            _bar(state.rightMotor, accent),
          ],
        );
      case TelemetryKind.speed:
        return _telemetryBox(
          scale: item.scale,
          children: [_row('VEL', '${state.speedPercent}%')],
        );
      case TelemetryKind.lastSignId:
        return _telemetryBox(
          scale: item.scale,
          children: [
            _row('ULT.', bluetoothService.lastSeenSignId.toString())
          ],
        );
      case TelemetryKind.variables:
        return _Variables(variables: variables, scale: item.scale);
    }
  }

  Widget _telemetryBox({
    required List<Widget> children,
    required double scale,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _bar(int value, Color accent) {
    final fraction = (value.abs() / 255).clamp(0.0, 1.0);
    final isReverse = value < 0;
    return SizedBox(
      width: 90,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Align(
          alignment: isReverse ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: isReverse ? Colors.redAccent : accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  final Sign? sign;
  final double scale;
  const _SignCard({required this.sign, required this.scale});

  @override
  Widget build(BuildContext context) {
    if (sign == null) {
      return Container(
        padding: EdgeInsets.all(8 * scale),
        decoration: BoxDecoration(
          color: const Color(0xCC1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined,
                size: 36 * scale, color: Colors.white24),
            SizedBox(width: 8 * scale),
            Text('Sin senal',
                style: TextStyle(fontSize: 12 * scale, color: Colors.white38)),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sampleThumb(sign!, 56 * scale),
          SizedBox(width: 10 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sign!.name,
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              Text('ID ${sign!.id}',
                  style: TextStyle(
                    fontSize: 10 * scale,
                    fontFamily: 'monospace',
                    color: Colors.white38,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sampleThumb(Sign sign, double size) {
    if (sign.image.isGallery) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(sign.image.assetPath!),
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                SignThumb(image: sign.image, size: size)),
      );
    }
    return SignThumb(image: sign.image, size: size);
  }
}

class _CurrentBlock extends StatelessWidget {
  final ExecutionState state;
  final double scale;
  const _CurrentBlock({required this.state, required this.scale});

  @override
  Widget build(BuildContext context) {
    final running = state.running && state.currentBlock != null;
    return Container(
      constraints: BoxConstraints(maxWidth: 200 * scale),
      padding:
          EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            running
                ? 'BLOQUE ${state.currentIndex + 1}/${state.totalBlocks}'
                : 'EN ESPERA',
            style: TextStyle(
              fontSize: 9 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.white54,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            running
                ? _shortDescribe(state.currentBlock!.runtimeType.toString())
                : '-',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11 * scale,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _shortDescribe(String type) {
    return type.replaceAll('Block', '');
  }
}

class _Variables extends StatelessWidget {
  final VariableStore variables;
  final double scale;
  const _Variables({required this.variables, required this.scale});

  @override
  Widget build(BuildContext context) {
    final all = <MapEntry<String, int>>[
      ...variables.localsView.entries,
      ...variables.globalsView.entries,
    ];
    return Container(
      constraints: BoxConstraints(maxWidth: 160 * scale),
      padding:
          EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('VARIABLES',
              style: TextStyle(
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.5)),
          if (all.isEmpty)
            Text('-', style: TextStyle(fontSize: 11 * scale, color: Colors.white38))
          else
            ...all.map((e) => Text(
                  '${e.key} = ${e.value}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11 * scale,
                    color: Colors.white,
                  ),
                )),
        ],
      ),
    );
  }
}
