import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Variables locales (por ejecucion) y globales (persistidas).
/// Convencion: nombre con `$` al principio = global.
class VariableStore {
  static const _key = 'global_vars_json';
  final SharedPreferences _prefs;
  final Map<String, int> _locals = {};
  final Map<String, int> _globals;

  VariableStore(this._prefs)
      : _globals = _loadGlobals(_prefs);

  static Map<String, int> _loadGlobals(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  bool _isGlobal(String name) => name.startsWith(r'$');

  int get(String name) {
    if (_isGlobal(name)) return _globals[name] ?? 0;
    return _locals[name] ?? 0;
  }

  void set(String name, int value) {
    if (_isGlobal(name)) {
      _globals[name] = value;
      _persist();
    } else {
      _locals[name] = value;
    }
  }

  void change(String name, int delta) {
    set(name, get(name) + delta);
  }

  /// Reset solo los locales — los globales persisten.
  void resetLocals() {
    _locals.clear();
  }

  Map<String, int> get globalsView => Map.unmodifiable(_globals);
  Map<String, int> get localsView => Map.unmodifiable(_locals);

  void _persist() {
    _prefs.setString(_key, jsonEncode(_globals));
  }
}
