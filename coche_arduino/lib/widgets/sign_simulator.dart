import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/sign_repository.dart';
import 'sign_overlay.dart';

/// Boton flotante visible solo en modo demo. Abre una hoja con la lista
/// de senales configuradas y, al tocar una, llama a
/// [BluetoothService.simulateSignDetected]. Tambien tiene una opcion
/// "Sin senal" (id 0) para limpiar el overlay.
class SignSimulatorButton extends StatelessWidget {
  final BluetoothService bluetoothService;
  final SignRepository repository;

  const SignSimulatorButton({
    super.key,
    required this.bluetoothService,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'sign-simulator',
      onPressed: () => _open(context),
      icon: const Icon(Icons.science_outlined, size: 18),
      label: const Text('Simular senal',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF2A2A2A),
      foregroundColor: Colors.amberAccent,
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (sheetContext) {
        final signs = repository.signs;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'SIMULAR DETECCION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white54,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.white38),
                title: const Text('Sin senal', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  'Limpia el overlay (id 0)',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                onTap: () {
                  bluetoothService.simulateSignDetected(0);
                  Navigator.of(sheetContext).pop();
                },
              ),
              if (signs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay senales configuradas. Crea una en "Senales".',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                )
              else
                ...signs.map(
                  (sign) => ListTile(
                    leading: SignThumb(image: sign.image, size: 36),
                    title: Text(sign.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      'ID ${sign.id}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    onTap: () {
                      bluetoothService.simulateSignDetected(sign.id);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
