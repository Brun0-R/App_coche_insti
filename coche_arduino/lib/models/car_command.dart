import 'dart:convert';
import 'dart:typed_data';

class CarCommand {
  final int x;
  final int y;

  const CarCommand(this.x, this.y);

  static const stop = CarCommand(0, 0);

  String encode() => 'X${x}Y$y\n';

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(encode()));
}
