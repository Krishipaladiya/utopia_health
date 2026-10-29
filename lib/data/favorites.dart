import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starred medicines, kept on the phone.
class FavoriteRemedies extends ChangeNotifier {
  static const _key = 'favorite_remedies';

  final Set<String> _names = {};
  bool _loaded = false;

  bool contains(String name) => _names.contains(name);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _names.addAll(prefs.getStringList(_key) ?? const []);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggle(String name) async {
    if (!_names.remove(name)) _names.add(name);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _names.toList());
    } catch (_) {}
  }
}

final favoriteRemedies = FavoriteRemedies();
