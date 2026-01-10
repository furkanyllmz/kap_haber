import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/saved_news_service.dart';
import '../models/news_item.dart';
import '../widgets/ticker_logo.dart';
import 'news_detail_screen.dart';

class SavedNewsScreen extends StatelessWidget {
  const SavedNewsScreen({super.key});

  static const Color primaryDark = Color(0xFF002B3A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Kaydedilenler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : primaryDark,
          ),
        ),
      ),
      body: Consumer<SavedNewsService>(
        builder: (context, savedService, child) {
          final savedNews = savedService.savedNews;
          
          if (savedNews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz kaydettiğiniz haber yok',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Haberleri kaydetmek için detay sayfasında\nyer imi simgesine dokunun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: savedNews.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final news = savedNews[index];
              return Dismissible(
                key: Key(news.id ?? index.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  savedService.removeNews(news.id ?? '');
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: TickerLogo(
                    ticker: news.displayTicker,
                    size: 48,
                    borderRadius: 10,
                  ),
                  title: Text(
                    news.headline ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${news.displayTicker} • ${news.publishedAt?.date ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewsDetailScreen(news: news),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
