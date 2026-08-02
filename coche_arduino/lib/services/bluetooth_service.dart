import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show VoidCallback;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/car_command.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  StreamSubscription? _inputSubscription;
  VoidCallback? onDisconnected;

  final StreamController<int> _detectedSignController =
      StreamController<int>.broadcast();
  Stream<int> get detectedSignStream => _detectedSignController.stream;

  int _lastSeenSignId = 0;
  int get lastSeenSignId => _lastSeenSignId;

  String _inputBuffer = '';

  bool get isConnected => _connection?.isConnected ?? false;

  DateTime _lastSendTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minSendInterval = Duration(milliseconds: 50);

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      throw BluetoothServiceException('No se pudieron obtener los dispositivos emparejados. Verifica que el Bluetooth esta activado.');
    }
  }

  Stream<BluetoothDiscoveryResult> startDiscovery() {
    try {
      return FlutterBluetoothSerial.instance.startDiscovery();
    } catch (e) {
      throw BluetoothServiceException('No se pudo iniciar la busqueda. Verifica permisos y que el Bluetooth esta activado.');
    }
  }

  Future<void> cancelDiscovery() async {
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
  }

  Future<bool> get isBluetoothEnabled async {
    try {
      return await FlutterBluetoothSerial.instance.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    try {
      _connection = await BluetoothConnection.toAddress(device.address)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw BluetoothServiceException('Tiempo de conexion agotado. Asegurate de que el dispositivo esta encendido y cerca.');
    } catch (e) {
      throw BluetoothServiceException('No se pudo conectar a ${device.name ?? device.address}. Intentalo de nuevo.');
    }

    _inputBuffer = '';
    _inputSubscription = _connection!.input?.listen(
      _onInput,
      onDone: () {
        _connection = null;
        onDisconnected?.call();
      },
      onError: (_) {
        _connection = null;
        onDisconnected?.call();
      },
    );
  }

  void _onInput(Uint8List data) {
    _inputBuffer += utf8.decode(data, allowMalformed: true);
    while (true) {
      final newlineIndex = _inputBuffer.indexOf('\n');
      if (newlineIndex < 0) {
        if (_inputBuffer.length > 64) _inputBuffer = '';
        break;
      }
      final line = _inputBuffer.substring(0, newlineIndex).trim();
      _inputBuffer = _inputBuffer.substring(newlineIndex + 1);
      if (line.isEmpty) continue;
      _handleLine(line);
    }
  }

  void _handleLine(String line) {
    if (line.startsWith('S')) {
      final id = int.tryParse(line.substring(1));
      if (id != null) {
        _lastSeenSignId = id;
        _detectedSignController.add(id);
      }
    }
  }

  Future<void> disconnect() async {
    _inputSubscription?.cancel();
    _inputSubscription = null;

    if (_connection != null) {
      try {
        await _connection!.finish();
      } catch (_) {}
      _connection = null;
    }
  }

  void sendCommand(int x, int y) {
    if (!isConnected) return;

    final now = DateTime.now();
    if (now.difference(_lastSendTime) < _minSendInterval) return;

    _lastSendTime = now;
    try {
      _connection!.output.add(CarCommand(x, y).toBytes());
    } catch (_) {
      _connection = null;
      onDisconnected?.call();
    }
  }

  void sendStop() {
    if (!isConnected) return;
    _lastSendTime = DateTime.now();
    try {
      _connection!.output.add(CarCommand.stop.toBytes());
    } catch (_) {
      _connection = null;
      onDisconnected?.call();
    }
  }

  void sendTrainCommand(int signalId, int photoCount) {
    if (!isConnected) return;
    final n = photoCount.clamp(1, 20);
    final line = 'T$signalId:$n\n';
    try {
      _connection!.output.add(Uint8List.fromList(utf8.encode(line)));
    } catch (_) {
      _connection = null;
      onDisconnected?.call();
    }
  }

  void sendForget() {
    if (!isConnected) return;
    try {
      _connection!.output.add(Uint8List.fromList(utf8.encode('R\n')));
    } catch (_) {
      _connection = null;
      onDisconnected?.call();
    }
  }

  /// Cambia el algoritmo del HuskyLens. 0..6 segun [HuskyAlgorithm].
  void sendAlgorithm(int algorithm) {
    if (!isConnected) return;
    try {
      _connection!
          .output
          .add(Uint8List.fromList(utf8.encode('M$algorithm\n')));
    } catch (_) {
      _connection = null;
      onDisconnected?.call();
    }
  }

  /// Inyecta una deteccion de senal sin Bluetooth: util para el modo demo.
  void simulateSignDetected(int id) {
    _lastSeenSignId = id;
    _detectedSignController.add(id);
  }

  void dispose() {
    _detectedSignController.close();
    disconnect();
  }
}

class BluetoothServiceException implements Exception {
  final String message;
  const BluetoothServiceException(this.message);

  @override
  String toString() => message;
}
