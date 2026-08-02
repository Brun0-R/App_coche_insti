import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/action_executor.dart';
import '../services/bluetooth_service.dart';
import 'control_screen.dart';

class BluetoothScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final ActionExecutor executor;

  const BluetoothScreen({
    super.key,
    required this.bluetoothService,
    required this.executor,
  });

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<BluetoothDevice> _bondedDevices = [];
  final List<BluetoothDiscoveryResult> _discoveredDevices = [];
  bool _isLoading = true;
  bool _isDiscovering = false;
  bool _bluetoothEnabled = true;
  bool _permissionsGranted = false;
  String? _connectingAddress;
  String? _errorMessage;
  StreamSubscription? _discoverySubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermissions();
    if (_permissionsGranted) {
      await _checkBluetoothState();
      if (_bluetoothEnabled) {
        await _loadBondedDevices();
      }
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    setState(() {
      _permissionsGranted = allGranted;
      if (!allGranted) {
        _isLoading = false;
        _errorMessage = 'Se necesitan permisos de Bluetooth y ubicacion para buscar dispositivos.';
      }
    });
  }

  Future<void> _checkBluetoothState() async {
    final enabled = await widget.bluetoothService.isBluetoothEnabled;
    setState(() {
      _bluetoothEnabled = enabled;
      if (!enabled) {
        _isLoading = false;
        _errorMessage = 'El Bluetooth esta desactivado. Activalo desde los ajustes de Android.';
      }
    });
  }

  Future<void> _loadBondedDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _checkBluetoothState();
      if (!_bluetoothEnabled) return;

      final devices = await widget.bluetoothService.getBondedDevices();
      if (mounted) {
        setState(() {
          _bondedDevices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startDiscovery() {
    setState(() {
      _discoveredDevices.clear();
      _isDiscovering = true;
    });

    _discoverySubscription = widget.bluetoothService.startDiscovery().listen(
      (result) {
        final isDuplicate = _discoveredDevices.any(
          (d) => d.device.address == result.device.address,
        );
        final isBonded = _bondedDevices.any(
          (d) => d.address == result.device.address,
        );
        if (!isDuplicate && !isBonded) {
          setState(() => _discoveredDevices.add(result));
        }
      },
      onDone: () {
        if (mounted) setState(() => _isDiscovering = false);
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isDiscovering = false);
          _showError('Error durante la busqueda: $e');
        }
      },
    );
  }

  void _stopDiscovery() {
    _discoverySubscription?.cancel();
    widget.bluetoothService.cancelDiscovery();
    setState(() => _isDiscovering = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectingAddress != null) return;
    setState(() => _connectingAddress = device.address);

    try {
      await widget.bluetoothService.connect(device);
      if (mounted) {
        _navigateToControl(device.name ?? 'Dispositivo');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _connectingAddress = null);
    }
  }

  void _enterDemoMode() {
    _navigateToControl('Modo demo');
  }

  void _navigateToControl(String deviceName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ControlScreen(
          bluetoothService: widget.bluetoothService,
          executor: widget.executor,
          deviceName: deviceName,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coche Arduino'),
        actions: [
          if (_isDiscovering)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopDiscovery,
              tooltip: 'Detener busqueda',
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _permissionsGranted && _bluetoothEnabled
                  ? _startDiscovery
                  : null,
              tooltip: 'Buscar dispositivos',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _init,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _enterDemoMode,
        icon: const Icon(Icons.gamepad_outlined),
        label: const Text('Sin conexion'),
        backgroundColor: const Color(0xFF2A2A2A),
        foregroundColor: Colors.white70,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _bondedDevices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _init,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildSectionHeader('Dispositivos emparejados'),
        if (_bondedDevices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No hay dispositivos emparejados.\nEmpareja tu HC-05 desde los ajustes de Android.',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._bondedDevices.map(_buildDeviceTile),
        if (_isDiscovering || _discoveredDevices.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader('Dispositivos encontrados'),
          if (_isDiscovering && _discoveredDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Buscando...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ..._discoveredDevices.map((r) => _buildDeviceTile(r.device)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device) {
    final isConnecting = _connectingAddress == device.address;
    final isOtherConnecting = _connectingAddress != null && !isConnecting;

    return ListTile(
      leading: const Icon(Icons.bluetooth, color: Colors.white54),
      title: Text(
        device.name ?? 'Desconocido',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        device.address,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      trailing: isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white.withValues(alpha: isOtherConnecting ? 0.1 : 0.3),
            ),
      enabled: !isOtherConnecting,
      onTap: isConnecting || isOtherConnecting
          ? null
          : () => _connectToDevice(device),
    );
  }
}
