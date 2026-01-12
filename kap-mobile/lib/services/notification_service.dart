import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_item.dart';
import '../models/news_item.dart';
import 'favorites_service.dart';

class NotificationService extends ChangeNotifier {
  static const String _notificationsKey = 'notifications';
  List<NotificationItem> _notifications = [];
  bool _initialized = false;

  NotificationService() {
    _loadNotifications();
  }

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString(_notificationsKey);
    
    if (notificationsJson != null) {
      final List<dynamic> decoded = json.decode(notificationsJson);
      _notifications = decoded.map((item) => NotificationItem.fromJson(item)).toList();
      // Sort by timestamp descending
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String notificationsJson = json.encode(
      _notifications.map((n) => n.toJson()).toList(),
    );
    await prefs.setString(_notificationsKey, notificationsJson);
  }

  Future<void> addNotification(NotificationItem notification) async {
    // Check if duplicate (e.g. same news id)
    if (_notifications.any((n) => n.id == notification.id)) return;

    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveNotifications();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
    notifyListeners();
  }

  /// Parse news date string (YYYY-MM-DD) to DateTime
  DateTime? _parseNewsDate(NewsItem item) {
    try {
      final dateStr = item.publishedAt?.date;
      final timeStr = item.publishedAt?.time ?? '00:00';
      if (dateStr == null) return null;
      
      // Parse date (YYYY-MM-DD)
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      
      // Parse time (HH:MM)
      final timeParts = timeStr.split(':');
      int hour = 0;
      int minute = 0;
      if (timeParts.length >= 2) {
        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }
      
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        hour,
        minute,
      );
    } catch (e) {
      return null;
    }
  }


  // Check new news against favorites - only notify for news AFTER favorite was added
  Future<void> checkNewsForFavorites(
    List<NewsItem> news, 
    List<String> favorites,
    FavoritesService favoritesService,
  ) async {
    if (!_initialized) await _loadNotifications();

    bool added = false;
    for (var item in news) {
      final ticker = item.displayTicker;
      if (favorites.contains(ticker)) {
        // Get when this favorite was added
        final favoriteAddedTime = favoritesService.getFavoriteAddedTime(ticker);
        
        // If we don't have a timestamp (old favorite), skip notification for old news
        if (favoriteAddedTime == null) continue;
        
        // Parse the news publish date
        final newsPublishTime = _parseNewsDate(item);
        if (newsPublishTime == null) continue;
        
        // Only notify if news was published AFTER the favorite was added
        if (newsPublishTime.isBefore(favoriteAddedTime)) continue;
        
        // Create a notification for this favorited stock
        final notification = NotificationItem(
          id: item.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: '$ticker - Yeni Haber!',
          body: item.headline ?? 'İlgilendiğiniz hisseden yeni bir bildirim var.',
          timestamp: newsPublishTime,
          relatedNews: item,
          ticker: ticker,
        );

        // Check if already notified
        if (!_notifications.any((n) => n.id == notification.id)) {
          _notifications.insert(0, notification);
          added = true;
        }
      }
    }

    if (added) {
      await _saveNotifications();
      notifyListeners();
    }
  }
}
