import 'package:flutter/foundation.dart';
import '../models/macro.dart';
import 'preferences_service.dart';

class MacroRepository extends ChangeNotifier {
  final PreferencesService _prefs;
  late List<Macro> _items;

  MacroRepository(this._prefs) {
    _items = _prefs.macros;
  }

  List<Macro> get items => List.unmodifiable(_items);

  Macro? byId(String id) {
    for (final m in _items) {
      if (m.id == id) return m;
    }
    return null;
  }

  void add(Macro m) {
    _items.add(m);
    _persist();
  }

  void update(Macro m) {
    final i = _items.indexWhere((e) => e.id == m.id);
    if (i < 0) {
      _items.add(m);
    } else {
      _items[i] = m;
    }
    _persist();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    _persist();
  }

  void _persist() {
    _prefs.macros = _items;
    notifyListeners();
  }
}
