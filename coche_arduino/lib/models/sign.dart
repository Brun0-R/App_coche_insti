import 'package:flutter/material.dart';
import 'action_block.dart';

class SignImage {
  final String? assetPath;
  final int? presetIconCode;

  const SignImage._({this.assetPath, this.presetIconCode});

  const SignImage.gallery(String path) : this._(assetPath: path);
  SignImage.preset(IconData icon) : this._(presetIconCode: icon.codePoint);
  const SignImage.empty() : this._();

  bool get isEmpty => assetPath == null && presetIconCode == null;
  bool get isGallery => assetPath != null;
  bool get isPreset => presetIconCode != null;

  IconData? get icon => presetIconCode == null
      ? null
      : IconData(presetIconCode!, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {
        if (assetPath != null) 'assetPath': assetPath,
        if (presetIconCode != null) 'presetIconCode': presetIconCode,
      };

  factory SignImage.fromJson(Map<String, dynamic> json) => SignImage._(
        assetPath: json['assetPath'] as String?,
        presetIconCode: json['presetIconCode'] as int?,
      );
}

class Sign {
  int id;
  String name;
  SignImage image;
  List<ActionBlock> sequence;

  Sign({
    required this.id,
    required this.name,
    this.image = const SignImage.empty(),
    List<ActionBlock>? sequence,
  }) : sequence = sequence ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image.toJson(),
        'sequence': sequence.map((b) => b.toJson()).toList(),
      };

  factory Sign.fromJson(Map<String, dynamic> json) => Sign(
        id: json['id'] as int,
        name: json['name'] as String,
        image: SignImage.fromJson(
            (json['image'] as Map?)?.cast<String, dynamic>() ?? {}),
        sequence: (json['sequence'] as List? ?? [])
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Sign copy() => Sign(
        id: id,
        name: name,
        image: image,
        sequence: sequence.map((b) => b.copy()).toList(),
      );
}

class PresetIcons {
  static const List<IconData> all = [
    Icons.stop,
    Icons.do_not_disturb_on,
    Icons.warning_amber,
    Icons.priority_high,
    Icons.arrow_upward,
    Icons.arrow_downward,
    Icons.arrow_back,
    Icons.arrow_forward,
    Icons.turn_left,
    Icons.turn_right,
    Icons.u_turn_left,
    Icons.u_turn_right,
    Icons.local_parking,
    Icons.directions_walk,
    Icons.construction,
    Icons.traffic,
    Icons.speed,
    Icons.flag,
    Icons.star,
    Icons.circle,
  ];
}
