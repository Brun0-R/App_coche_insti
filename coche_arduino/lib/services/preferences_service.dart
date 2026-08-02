import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/macro.dart';
import '../models/program.dart';
import '../models/sign.dart';
import '../widgets/joystick_editor.dart';

class PreferencesService {
  static const _keySpeedPercent = 'speed_percent';
  static const _keyJoystickX = 'joystick_x';
  static const _keyJoystickY = 'joystick_y';
  static const _keyJoystickSize = 'joystick_size';
  static const _keySigns = 'signs_json';
  static const _keyTrainPhotoCount = 'train_photo_count';
  static const _keyOverlayFracX = 'overlay_frac_x';
  static const _keyOverlayFracY = 'overlay_frac_y';
  static const _keyOverlayScale = 'overlay_scale';
  // Perfiles independientes por modo (joystick / dual). Si no existen,
  // hacen fallback al perfil legacy compartido (las constantes de arriba).
  static const _keyOverlayJoyFracX = 'overlay_joy_frac_x';
  static const _keyOverlayJoyFracY = 'overlay_joy_frac_y';
  static const _keyOverlayJoyScale = 'overlay_joy_scale';
  static const _keyOverlayDualFracX = 'overlay_dual_frac_x';
  static const _keyOverlayDualFracY = 'overlay_dual_frac_y';
  static const _keyOverlayDualScale = 'overlay_dual_scale';
  static const _keyLastMode = 'last_mode';
  static const _keyPrograms = 'programs_json';
  static const _keyMacros = 'macros_json';
  static const _keyTelemetryConfig = 'telemetry_config_json';
  static const _keyHuskyAlgorithm = 'husky_algorithm';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  int get speedPercent => _prefs.getInt(_keySpeedPercent) ?? 100;
  set speedPercent(int v) => _prefs.setInt(_keySpeedPercent, v);

  JoystickConfig get joystickConfig => JoystickConfig(
        position: Offset(
          _prefs.getDouble(_keyJoystickX) ?? 0,
          _prefs.getDouble(_keyJoystickY) ?? 0,
        ),
        sizeFactor: _prefs.getDouble(_keyJoystickSize) ?? 0.70,
      );

  set joystickConfig(JoystickConfig config) {
    _prefs.setDouble(_keyJoystickX, config.position.dx);
    _prefs.setDouble(_keyJoystickY, config.position.dy);
    _prefs.setDouble(_keyJoystickSize, config.sizeFactor);
  }

  int get trainPhotoCount => _prefs.getInt(_keyTrainPhotoCount) ?? 5;
  set trainPhotoCount(int v) =>
      _prefs.setInt(_keyTrainPhotoCount, v.clamp(1, 20));

  List<Sign> get signs {
    final raw = _prefs.getString(_keySigns);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Sign.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  set signs(List<Sign> value) {
    final raw = jsonEncode(value.map((s) => s.toJson()).toList());
    _prefs.setString(_keySigns, raw);
  }

  // Posicion (fraccion 0..1 del ancho/alto) y escala del chip overlay,
  // independiente para Joystick y Dual.
  Offset overlayPositionFrac(OverlayProfile profile) {
    final keys = _overlayKeys(profile);
    final legacyX = _prefs.getDouble(_keyOverlayFracX);
    final legacyY = _prefs.getDouble(_keyOverlayFracY);
    return Offset(
      _prefs.getDouble(keys.x) ?? legacyX ?? 0.78,
      _prefs.getDouble(keys.y) ?? legacyY ?? 0.04,
    );
  }

  void setOverlayPositionFrac(OverlayProfile profile, Offset v) {
    final keys = _overlayKeys(profile);
    _prefs.setDouble(keys.x, v.dx);
    _prefs.setDouble(keys.y, v.dy);
  }

  double overlayScale(OverlayProfile profile) {
    final keys = _overlayKeys(profile);
    return _prefs.getDouble(keys.scale) ??
        _prefs.getDouble(_keyOverlayScale) ??
        1.0;
  }

  void setOverlayScale(OverlayProfile profile, double v) {
    _prefs.setDouble(_overlayKeys(profile).scale, v);
  }

  _OverlayKeys _overlayKeys(OverlayProfile profile) =>
      profile == OverlayProfile.joystick
          ? const _OverlayKeys(_keyOverlayJoyFracX, _keyOverlayJoyFracY,
              _keyOverlayJoyScale)
          : const _OverlayKeys(_keyOverlayDualFracX, _keyOverlayDualFracY,
              _keyOverlayDualScale);

  /// 'joystick' | 'dual' | 'auto'
  String get lastMode => _prefs.getString(_keyLastMode) ?? 'joystick';
  set lastMode(String v) => _prefs.setString(_keyLastMode, v);

  List<Program> get programs {
    final raw = _prefs.getString(_keyPrograms);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Program.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  set programs(List<Program> value) {
    _prefs.setString(
        _keyPrograms, jsonEncode(value.map((p) => p.toJson()).toList()));
  }

  List<Macro> get macros {
    final raw = _prefs.getString(_keyMacros);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Macro.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  set macros(List<Macro> value) {
    _prefs.setString(
        _keyMacros, jsonEncode(value.map((m) => m.toJson()).toList()));
  }

  String? get telemetryConfigJson => _prefs.getString(_keyTelemetryConfig);
  set telemetryConfigJson(String? v) {
    if (v == null) {
      _prefs.remove(_keyTelemetryConfig);
    } else {
      _prefs.setString(_keyTelemetryConfig, v);
    }
  }

  /// Algoritmo del HuskyLens (0..6, ver constantes en `bluetooth_service`).
  int get huskyAlgorithm => _prefs.getInt(_keyHuskyAlgorithm) ?? 6;
  set huskyAlgorithm(int v) => _prefs.setInt(_keyHuskyAlgorithm, v);

  SharedPreferences get raw => _prefs;
}

/// Pantalla a la que pertenece un perfil de overlay.
enum OverlayProfile { joystick, dual }

class _OverlayKeys {
  final String x;
  final String y;
  final String scale;
  const _OverlayKeys(this.x, this.y, this.scale);
}
