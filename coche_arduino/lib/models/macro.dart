/// Un punto muestreado de la grabacion del joystick.
class MacroSample {
  /// Milisegundos relativos al inicio de la grabacion.
  final int t;
  final int x;
  final int y;

  const MacroSample(this.t, this.x, this.y);

  Map<String, dynamic> toJson() => {'t': t, 'x': x, 'y': y};

  factory MacroSample.fromJson(Map<String, dynamic> json) => MacroSample(
        json['t'] as int,
        json['x'] as int,
        json['y'] as int,
      );
}

class Macro {
  String id;
  String name;
  List<MacroSample> samples;

  Macro({
    required this.id,
    required this.name,
    List<MacroSample>? samples,
  }) : samples = samples ?? [];

  /// Duracion total en ms (timestamp del ultimo punto).
  int get durationMs => samples.isEmpty ? 0 : samples.last.t;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'samples': samples.map((s) => s.toJson()).toList(),
      };

  factory Macro.fromJson(Map<String, dynamic> json) => Macro(
        id: json['id'] as String,
        name: json['name'] as String,
        samples: (json['samples'] as List? ?? [])
            .map((e) => MacroSample.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Macro copy() => Macro(
        id: id,
        name: name,
        samples: List.of(samples),
      );
}
