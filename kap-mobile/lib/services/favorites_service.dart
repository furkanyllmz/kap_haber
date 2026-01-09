import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService extends ChangeNotifier {
  static const String _favoritesKey = 'favorite_stocks';
  List<String> _favorites = []; // Favori hisse kodlarını tutar
  bool _initialized = false;

  FavoritesService() {
    _loadFavorites();
  }

  List<String> get favorites => _favorites;

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList(_favoritesKey) ?? [];
    _initialized = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(String ticker) async {
    if (!_initialized) await _loadFavorites();

    if (_favorites.contains(ticker)) {
      _favorites.remove(ticker);
    } else {
      _favorites.add(ticker);
    }
    
    // Değişikliği kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites);
    
    notifyListeners();
  }

  bool isFavorite(String ticker) {
    return _favorites.contains(ticker);
  }
}
