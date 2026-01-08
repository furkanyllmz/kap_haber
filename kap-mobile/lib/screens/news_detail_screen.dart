import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ticker_logo.dart';
import '../models/news_item.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsItem news;

  const NewsDetailScreen({super.key, required this.news});

  Color _getTickerColor(String ticker) {
    return const Color(0xFF1A237E);
  }

  Widget _buildLogo(String ticker) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: TickerLogo(
        ticker: ticker,
        size: 72,
        borderRadius: 16,
      ),
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticker = news.displayTicker;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).iconTheme.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          ticker,
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (news.url != null)
             Padding(
               padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                 icon: Icon(Icons.share_outlined, color: Theme.of(context).iconTheme.color),
                 onPressed: () => _openUrl(news.url),
                ),
             ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Üst Kart
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildLogo(ticker),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             if (news.category != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  news.category!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ticker,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).hintColor),
                                const SizedBox(width: 4),
                                Text(
                                  news.publishedAt?.date ?? '',
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time_rounded, size: 14, color: Theme.of(context).hintColor),
                                const SizedBox(width: 4),
                                Text(
                                  news.displayTime,
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    news.headline ?? '',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description & Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description / Body Text
                  if (news.description.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                         // Simple cleanup for markdown bold syntax if desired, or display as is.
                         // For now, displaying as is but handling newlines.
                        news.description.replaceAll('**', '').replaceAll('- ', '• '), 
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                   // Facts / Important Info
                   if (news.facts != null && news.facts!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'ÖNEMLİ BİLGİLER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: news.facts!.where((f) => f.key != null && f.value != null).map((fact) {
                          final index = news.facts!.indexOf(fact);
                          final isLast = index == news.facts!.length - 1;
                          
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        fact.key!,
                                        style: TextStyle(
                                          color: Theme.of(context).hintColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        fact.value!,
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(height: 1, color: Theme.of(context).dividerColor, indent: 16, endIndent: 16),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                   if (news.url != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(news.url),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('KAP Bildirimini Görüntüle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
