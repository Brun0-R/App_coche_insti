import 'package:flutter/foundation.dart';
import '../models/program.dart';
import 'preferences_service.dart';

class ProgramRepository extends ChangeNotifier {
  final PreferencesService _prefs;
  late List<Program> _items;

  ProgramRepository(this._prefs) {
    _items = _prefs.programs;
  }

  List<Program> get items => List.unmodifiable(_items);

  Program? byId(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  void add(Program p) {
    _items.add(p);
    _persist();
  }

  void update(Program p) {
    final i = _items.indexWhere((e) => e.id == p.id);
    if (i < 0) {
      _items.add(p);
    } else {
      _items[i] = p;
    }
    _persist();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    _persist();
  }

  void _persist() {
    _prefs.programs = _items;
    notifyListeners();
  }
}
