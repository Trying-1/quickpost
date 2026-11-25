import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton manager for user's favorite fonts across the app.
class FavoriteFontsManager extends ChangeNotifier {
  FavoriteFontsManager._();
  static final FavoriteFontsManager _instance = FavoriteFontsManager._();
  factory FavoriteFontsManager() => _instance;

  static const String _prefsKey = 'favorite_font_families_v1';

  final Set<String> _favoriteFamilies = {};
  bool _initialized = false;

  /// Unmodifiable set of favorite font family names.
  Set<String> get favoriteFamilies => Set.unmodifiable(_favoriteFamilies);

  /// Total count of favorite fonts.
  int get count => _favoriteFamilies.length;

  /// Initialize and load saved favorites from SharedPreferences.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      if (list != null) {
        _favoriteFamilies.addAll(list);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FavoriteFontsManager init error: $e');
    }
  }

  /// Check whether a font family is favorited.
  bool isFavorite(String family) {
    return _favoriteFamilies.contains(family);
  }

  /// Toggle favorite status of a font family.
  Future<bool> toggleFavorite(String family) async {
    final willBeFavorite = !_favoriteFamilies.contains(family);
    if (willBeFavorite) {
      _favoriteFamilies.add(family);
    } else {
      _favoriteFamilies.remove(family);
    }
    notifyListeners();
    await _persist();
    return willBeFavorite;
  }

  /// Add a font family to favorites.
  Future<void> addFavorite(String family) async {
    if (_favoriteFamilies.add(family)) {
      notifyListeners();
      await _persist();
    }
  }

  /// Remove a font family from favorites.
  Future<void> removeFavorite(String family) async {
    if (_favoriteFamilies.remove(family)) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _favoriteFamilies.toList());
    } catch (e) {
      debugPrint('Error persisting favorite fonts: $e');
    }
  }
}

