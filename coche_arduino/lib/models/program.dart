import 'action_block.dart';

/// Una secuencia de bloques con nombre que se puede reusar:
/// asignarse a una senal o ejecutarse manualmente.
class Program {
  String id;
  String name;
  List<ActionBlock> sequence;

  Program({
    required this.id,
    required this.name,
    List<ActionBlock>? sequence,
  }) : sequence = sequence ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sequence': sequence.map((b) => b.toJson()).toList(),
      };

  factory Program.fromJson(Map<String, dynamic> json) => Program(
        id: json['id'] as String,
        name: json['name'] as String,
        sequence: (json['sequence'] as List? ?? [])
            .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Program copy() => Program(
        id: id,
        name: name,
        sequence: sequence.map((b) => b.copy()).toList(),
      );
}
