import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StockProvider with ChangeNotifier {
  List<Map<String, dynamic>> _stocks = [];
  List<String> _favoriteTickers = [];
  List<String> _notificationTickers = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get stocks => _stocks;
  bool get isLoading => _isLoading;
  List<String> get favoriteTickers => _favoriteTickers;
  List<String> get notificationTickers => _notificationTickers;

  StockProvider() {
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _loadStocks(),
      _loadPreferences(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadStocks() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/stocks.json');
      final Map<String, dynamic> stocksMap = json.decode(jsonString);

      _stocks = stocksMap.entries.map((entry) {
        return {
          'ticker': entry.key,
          'name': entry.value,
        };
      }).toList();

      _stocks.sort((a, b) => a['ticker'].compareTo(b['ticker']));
    } catch (e) {
      debugPrint('Error loading stocks: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteTickers = prefs.getStringList('favorite_stocks') ?? [];
    _notificationTickers = prefs.getStringList('notification_stocks') ?? [];
  }

  bool isFavorite(String ticker) {
    return _favoriteTickers.contains(ticker);
  }

  bool isNotificationEnabled(String ticker) {
    return _notificationTickers.contains(ticker);
  }

  Future<void> toggleFavorite(String ticker) async {
    if (_favoriteTickers.contains(ticker)) {
      _favoriteTickers.remove(ticker);
    } else {
      _favoriteTickers.add(ticker);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_stocks', _favoriteTickers);
  }

  Future<void> toggleNotification(String ticker) async {
    if (_notificationTickers.contains(ticker)) {
      _notificationTickers.remove(ticker);
    } else {
      _notificationTickers.add(ticker);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notification_stocks', _notificationTickers);
  }
}
