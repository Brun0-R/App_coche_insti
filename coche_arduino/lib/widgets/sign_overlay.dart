import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/sign.dart';
import '../services/bluetooth_service.dart';
import '../services/sign_repository.dart';

/// Pequeno chip esquina-derecha que muestra la ultima senal detectada.
/// Solo informativo — no ejecuta acciones.
class SignOverlay extends StatefulWidget {
  final BluetoothService bluetoothService;
  final SignRepository repository;
  final double scale;

  const SignOverlay({
    super.key,
    required this.bluetoothService,
    required this.repository,
    this.scale = 1.0,
  });

  @override
  State<SignOverlay> createState() => _SignOverlayState();
}

class _SignOverlayState extends State<SignOverlay> {
  StreamSubscription<int>? _subscription;
  Sign? _currentSign;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _subscription =
        widget.bluetoothService.detectedSignStream.listen(_onSignDetected);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _onSignDetected(int id) {
    _hideTimer?.cancel();
    if (id <= 0) {
      _hideTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _currentSign = null);
      });
      return;
    }
    final sign = widget.repository.byId(id);
    if (sign == null) return;
    setState(() => _currentSign = sign);
  }

  @override
  Widget build(BuildContext context) {
    final sign = _currentSign;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: sign == null
          ? const SizedBox.shrink()
          : _buildChip(sign),
    );
  }

  Widget _buildChip(Sign sign) {
    final s = widget.scale;
    return Container(
      key: ValueKey('overlay-${sign.id}'),
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: const Color(0xCC1E1E1E),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignThumb(image: sign.image, size: 32 * s),
          SizedBox(width: 8 * s),
          Text(
            sign.name,
            style: TextStyle(
              fontSize: 12 * s,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista pequena de la imagen de una senal: archivo de galeria, icono
/// de Material o un placeholder vacio.
class SignThumb extends StatelessWidget {
  final SignImage image;
  final double size;

  const SignThumb({super.key, required this.image, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (image.isGallery) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(image.assetPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _placeholder(context),
        ),
      );
    }
    if (image.isPreset) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          image.icon,
          size: size * 0.65,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.help_outline, size: 18, color: Colors.white24),
    );
  }
}
