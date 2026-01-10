import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../widgets/ticker_logo.dart';
import '../models/news_item.dart';
import '../services/saved_news_service.dart';
import 'ticker_news_screen.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsItem news;

  const NewsDetailScreen({super.key, required this.news});

  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  static const String baseImageUrl = 'http://91.132.49.137:5296';

  String _getImageUrl() {
    if (news.imageUrl != null && news.imageUrl!.isNotEmpty) {
      if (news.imageUrl!.startsWith('http')) {
        return news.imageUrl!;
      }
      return '$baseImageUrl${news.imageUrl!.startsWith('/') ? '' : '/'}${news.imageUrl}';
    }
    // Fallback if somehow imageUrl is missing
    return '$baseImageUrl/banners/Diğer/diğer_1.png';
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _goToTickerPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TickerNewsScreen(
          ticker: news.displayTicker,
          companyName: news.displayTicker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticker = news.displayTicker;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Theme.of(context).colorScheme.primary : kapRed;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'KAP DETAY',
              style: TextStyle(
                color: kapRed,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              'Bildirim No: ${news.id ?? '-'}',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Share Button
          IconButton(
            icon: Icon(Icons.share_outlined, color: isDark ? Colors.white : primaryDark, size: 22),
            onPressed: () {
              final String shareUrl = 'https://kaphaber.com/news/${news.id}';
              Share.share('${news.headline}\n\nDetaylar: $shareUrl');
            },
          ),
          // Bookmark Button
          Consumer<SavedNewsService>(
            builder: (context, savedService, child) {
              final isSaved = savedService.isSaved(news.id ?? '');
              return IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? accentColor : (isDark ? Colors.white : primaryDark),
                  size: 22,
                ),
                onPressed: () {
                  savedService.toggleSave(news);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSaved ? 'Haber kaydedilenlerden çıkarıldı' : 'Haber kaydedildi'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ticker Header - Clickable
            GestureDetector(
              onTap: () => _goToTickerPage(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    TickerLogo(
                      ticker: ticker,
                      size: 48,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticker,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),

            // Headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                news.headline ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: isDark ? Colors.white : primaryDark,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Main Image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _getImageUrl(),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Icon(Icons.image, color: Colors.grey.shade400, size: 48),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Article Content from article_md
            if (news.seo?.articleMd != null && news.seo!.articleMd!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MarkdownBody(
                  data: news.seo!.articleMd!,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                    h2: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                    h3: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                    blockSpacing: 12,
                  ),
                  onTapLink: (text, href, title) {
                    if (href != null) _openUrl(href);
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Important Facts Table (Compact)
            if (news.facts != null && news.facts!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'ÖNEMLİ BİLGİLER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: news.facts!.where((f) => f.key != null && f.value != null).map((fact) {
                    final index = news.facts!.indexOf(fact);
                    final isLast = index == news.facts!.length - 1;
                    
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  fact.key!,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  fact.value!,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : primaryDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1, 
                            color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
                            indent: 12,
                            endIndent: 12,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Original PDF Button
            if (news.url != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(news.url),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    label: const Text("Kap Bildirimini Görüntüle"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.3,
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : primaryDark,
            ),
          ),
      ],
    );
  }
}
