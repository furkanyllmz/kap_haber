import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_item.dart';

class SavedNewsService extends ChangeNotifier {
  static const String _key = 'saved_news';
  List<NewsItem> _savedNews = [];

  List<NewsItem> get savedNews => _savedNews;

  SavedNewsService() {
    _loadSavedNews();
  }

  Future<void> _loadSavedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    _savedNews = jsonList.map((json) => NewsItem.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _savedNews.map((news) => jsonEncode(news.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  bool isSaved(String newsId) {
    return _savedNews.any((news) => news.id == newsId);
  }

  Future<void> toggleSave(NewsItem news) async {
    if (isSaved(news.id ?? '')) {
      _savedNews.removeWhere((n) => n.id == news.id);
    } else {
      _savedNews.insert(0, news);
    }
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> removeNews(String newsId) async {
    _savedNews.removeWhere((n) => n.id == newsId);
    await _saveToDisk();
    notifyListeners();
  }
}
