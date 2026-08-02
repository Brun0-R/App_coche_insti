import 'dart:convert';
import 'package:flutter/material.dart';

enum TelemetryKind {
  signCard,        // imagen + nombre de la senal activa
  currentBlock,    // bloque que se esta ejecutando
  direction,       // indicador 2D X/Y
  xy,              // texto X / Y
  leftMotor,       // valor + barra IZQ
  rightMotor,      // valor + barra DER
  speed,           // % de velocidad
  lastSignId,      // ID ultima vista
  variables,       // tabla de variables locales y globales
}

extension TelemetryKindLabel on TelemetryKind {
  String get label {
    switch (this) {
      case TelemetryKind.signCard:
        return 'Senal activa';
      case TelemetryKind.currentBlock:
        return 'Bloque actual';
      case TelemetryKind.direction:
        return 'Direccion';
      case TelemetryKind.xy:
        return 'X / Y';
      case TelemetryKind.leftMotor:
        return 'Motor IZQ';
      case TelemetryKind.rightMotor:
        return 'Motor DER';
      case TelemetryKind.speed:
        return 'Velocidad';
      case TelemetryKind.lastSignId:
        return 'Ultima senal ID';
      case TelemetryKind.variables:
        return 'Variables';
    }
  }

  IconData get icon {
    switch (this) {
      case TelemetryKind.signCard:
        return Icons.image;
      case TelemetryKind.currentBlock:
        return Icons.code;
      case TelemetryKind.direction:
        return Icons.explore;
      case TelemetryKind.xy:
        return Icons.swap_horiz;
      case TelemetryKind.leftMotor:
        return Icons.arrow_back;
      case TelemetryKind.rightMotor:
        return Icons.arrow_forward;
      case TelemetryKind.speed:
        return Icons.speed;
      case TelemetryKind.lastSignId:
        return Icons.tag;
      case TelemetryKind.variables:
        return Icons.list_alt;
    }
  }
}

class TelemetryItem {
  TelemetryKind kind;
  Offset positionFrac;
  double scale;
  bool visible;

  TelemetryItem({
    required this.kind,
    required this.positionFrac,
    this.scale = 1.0,
    this.visible = true,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'fx': positionFrac.dx,
        'fy': positionFrac.dy,
        'scale': scale,
        'visible': visible,
      };

  factory TelemetryItem.fromJson(Map<String, dynamic> json) => TelemetryItem(
        kind: TelemetryKind.values
            .firstWhere((k) => k.name == json['kind']),
        positionFrac:
            Offset((json['fx'] as num).toDouble(), (json['fy'] as num).toDouble()),
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        visible: json['visible'] as bool? ?? true,
      );
}

class TelemetryConfig {
  List<TelemetryItem> items;

  TelemetryConfig({required this.items});

  String toJsonString() => jsonEncode(items.map((i) => i.toJson()).toList());

  static TelemetryConfig fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return defaultConfig();
    try {
      final list = jsonDecode(raw) as List;
      return TelemetryConfig(
        items: list
            .map((e) => TelemetryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return defaultConfig();
    }
  }

  /// Configuracion por defecto: items en lados opuestos para no apinarse.
  static TelemetryConfig defaultConfig() {
    return TelemetryConfig(items: [
      // Lado izquierdo
      TelemetryItem(
          kind: TelemetryKind.signCard,
          positionFrac: const Offset(0.02, 0.18)),
      TelemetryItem(
          kind: TelemetryKind.currentBlock,
          positionFrac: const Offset(0.02, 0.55)),
      // Centro / abajo
      TelemetryItem(
          kind: TelemetryKind.direction,
          positionFrac: const Offset(0.42, 0.30)),
      TelemetryItem(
          kind: TelemetryKind.xy,
          positionFrac: const Offset(0.42, 0.62)),
      // Lado derecho
      TelemetryItem(
          kind: TelemetryKind.leftMotor,
          positionFrac: const Offset(0.74, 0.20)),
      TelemetryItem(
          kind: TelemetryKind.rightMotor,
          positionFrac: const Offset(0.74, 0.34)),
      TelemetryItem(
          kind: TelemetryKind.speed,
          positionFrac: const Offset(0.74, 0.50)),
      TelemetryItem(
          kind: TelemetryKind.lastSignId,
          positionFrac: const Offset(0.74, 0.62)),
      TelemetryItem(
          kind: TelemetryKind.variables,
          positionFrac: const Offset(0.74, 0.74),
          visible: false),
    ]);
  }
}
