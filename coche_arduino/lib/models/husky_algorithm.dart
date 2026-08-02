import 'package:flutter/material.dart';

/// Los 7 algoritmos del HuskyLens. El indice se manda al Arduino con el
/// comando `M<n>\n`. Coincide con el orden de las constantes
/// ALGORITHM_* de la libreria HUSKYLENSArduino.
class HuskyAlgorithm {
  final int code;
  final String name;
  final String description;
  final IconData icon;

  const HuskyAlgorithm({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
  });

  static const all = <HuskyAlgorithm>[
    HuskyAlgorithm(
      code: 0,
      name: 'Reconocimiento facial',
      description: 'Detecta caras y las identifica si las has aprendido.',
      icon: Icons.face,
    ),
    HuskyAlgorithm(
      code: 1,
      name: 'Seguimiento de objetos',
      description: 'Sigue un objeto que aprendas en movimiento.',
      icon: Icons.gps_fixed,
    ),
    HuskyAlgorithm(
      code: 2,
      name: 'Reconocimiento de objetos',
      description: 'Reconoce 20 categorias de objetos preentrenadas.',
      icon: Icons.category,
    ),
    HuskyAlgorithm(
      code: 3,
      name: 'Seguimiento de lineas',
      description: 'Sigue una linea, ideal para circuitos.',
      icon: Icons.timeline,
    ),
    HuskyAlgorithm(
      code: 4,
      name: 'Reconocimiento de colores',
      description: 'Aprende y detecta hasta 7 colores.',
      icon: Icons.palette,
    ),
    HuskyAlgorithm(
      code: 5,
      name: 'Reconocimiento de tags',
      description: 'Lee AprilTags (codigos visuales).',
      icon: Icons.qr_code_2,
    ),
    HuskyAlgorithm(
      code: 6,
      name: 'Clasificacion de objetos',
      description: 'Lo que usas hoy: clasifica imagenes que entrenes.',
      icon: Icons.image_search,
    ),
  ];

  static HuskyAlgorithm byCode(int code) {
    return all.firstWhere(
      (a) => a.code == code,
      orElse: () => all.last,
    );
  }
}
