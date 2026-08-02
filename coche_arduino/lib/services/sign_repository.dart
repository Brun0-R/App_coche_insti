import 'package:flutter/foundation.dart';
import '../models/sign.dart';
import 'preferences_service.dart';

class SignRepository extends ChangeNotifier {
  final PreferencesService _prefs;
  late List<Sign> _signs;

  SignRepository(this._prefs) {
    _signs = _prefs.signs;
  }

  List<Sign> get signs => List.unmodifiable(_signs);

  Sign? byId(int id) {
    for (final s in _signs) {
      if (s.id == id) return s;
    }
    return null;
  }

  int nextAvailableId() {
    final used = _signs.map((s) => s.id).toSet();
    for (var i = 1; i <= 50; i++) {
      if (!used.contains(i)) return i;
    }
    return _signs.length + 1;
  }

  void add(Sign sign) {
    _signs.add(sign);
    _persist();
  }

  void update(Sign sign) {
    final index = _signs.indexWhere((s) => s.id == sign.id);
    if (index < 0) {
      _signs.add(sign);
    } else {
      _signs[index] = sign;
    }
    _persist();
  }

  void remove(int id) {
    _signs.removeWhere((s) => s.id == id);
    _persist();
  }

  void _persist() {
    _prefs.signs = _signs;
    notifyListeners();
  }
}
