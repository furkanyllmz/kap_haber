import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../models/notification_item.dart';
import 'news_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryDark = const Color(0xFF002B3A);
    final kapRed = const Color(0xFFE30613);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Bildirimler',
          style: TextStyle(
            color: isDark ? Colors.white : primaryDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: isDark ? Colors.white70 : primaryDark.withValues(alpha: 0.7)),
            onPressed: () => context.read<NotificationService>().markAllAsRead(),
            tooltip: 'Tümünü okundu işaretle',
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: kapRed.withValues(alpha: 0.8)),
            onPressed: () => _confirmDeleteAll(context),
            tooltip: 'Tümünü temizle',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: Consumer<NotificationService>(
        builder: (context, service, child) {
          if (service.notifications.isEmpty) {
            return _buildEmptyState(isDark, primaryDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: service.notifications.length,
            itemBuilder: (context, index) {
              final notification = service.notifications[index];
              return _buildNotificationItem(context, notification, isDark, primaryDark, kapRed);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz bildirim yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Favori hisselerinizden haber geldiğinde burada görünecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, 
    NotificationItem notification, 
    bool isDark, 
    Color primaryDark,
    Color kapRed
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: kapRed,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => context.read<NotificationService>().removeNotification(notification.id),
      child: InkWell(
        onTap: () {
          context.read<NotificationService>().markAsRead(notification.id);
          if (notification.relatedNews != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewsDetailScreen(news: notification.relatedNews!),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead 
                ? Colors.transparent 
                : (isDark ? kapRed.withValues(alpha: 0.05) : kapRed.withValues(alpha: 0.03)),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E8F0),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator for unread
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kapRed,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 20),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                              color: isDark ? Colors.white : primaryDark,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    if (notification.ticker != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notification.ticker!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kapRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa';
    } else {
      return DateFormat('dd.MM.yyyy').format(date);
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Temizle'),
        content: const Text('Tüm bildirimleri silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              context.read<NotificationService>().clearAll();
              Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
