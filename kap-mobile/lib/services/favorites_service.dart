import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService extends ChangeNotifier {
  static const String _favoritesKey = 'favorite_stocks';
  static const String _favoriteTimestampsKey = 'favorite_timestamps';
  
  List<String> _favorites = []; // Favori hisse kodlarını tutar
  Map<String, DateTime> _favoriteTimestamps = {}; // Her favorinin eklenme zamanı
  bool _initialized = false;

  FavoritesService() {
    _loadFavorites();
  }

  List<String> get favorites => _favorites;
  
  /// Bir hissenin favorilere eklendiği zamanı döndürür
  DateTime? getFavoriteAddedTime(String ticker) {
    return _favoriteTimestamps[ticker];
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList(_favoritesKey) ?? [];
    
    // Timestamp'leri yükle
    final timestampsJson = prefs.getString(_favoriteTimestampsKey);
    if (timestampsJson != null) {
      final Map<String, dynamic> decoded = json.decode(timestampsJson);
      _favoriteTimestamps = decoded.map((key, value) => 
        MapEntry(key, DateTime.parse(value as String))
      );
    }
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> toSave = _favoriteTimestamps.map((key, value) => 
      MapEntry(key, value.toIso8601String())
    );
    await prefs.setString(_favoriteTimestampsKey, json.encode(toSave));
  }

  Future<void> toggleFavorite(String ticker) async {
    if (!_initialized) await _loadFavorites();

    if (_favorites.contains(ticker)) {
      _favorites.remove(ticker);
      _favoriteTimestamps.remove(ticker); // Timestamp'i de sil
    } else {
      _favorites.add(ticker);
      _favoriteTimestamps[ticker] = DateTime.now(); // Eklenme zamanını kaydet
    }
    
    // Değişikliği kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites);
    await _saveTimestamps();
    
    notifyListeners();
  }

  bool isFavorite(String ticker) {
    return _favorites.contains(ticker);
  }
}
