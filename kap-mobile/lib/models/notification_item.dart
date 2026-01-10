import 'package:kap_mobil/models/news_item.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final NewsItem? relatedNews;
  final String? ticker;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.relatedNews,
    this.ticker,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'relatedNews': relatedNews?.toJson(),
      'ticker': ticker,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      relatedNews: json['relatedNews'] != null 
          ? NewsItem.fromJson(json['relatedNews']) 
          : null,
      ticker: json['ticker'],
    );
  }
}
