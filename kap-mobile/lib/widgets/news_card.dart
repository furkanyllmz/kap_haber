import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/news_item.dart';
import 'ticker_logo.dart';

class NewsCard extends StatelessWidget {
  final NewsItem news;
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.news,
    this.onTap,
  });

  Widget _buildLogo(String ticker) {
    return TickerLogo(
      ticker: ticker,
      size: 50,
      borderRadius: 10,
    );
  }

  Color _getTickerColor(String ticker) {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFF44336),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFF795548),
      const Color(0xFF607D8B),
    ];
    return colors[ticker.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final ticker = news.displayTicker;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol taraftaki logo
              _buildLogo(ticker),
              const SizedBox(width: 14),
              // Sağ taraftaki içerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: Ticker badge + Saat + Kategori
                    Row(
                      children: [
                        // Ticker badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getTickerColor(ticker).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ticker,
                            style: TextStyle(
                              color: _getTickerColor(ticker),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Saat
                        Icon(Icons.access_time, size: 12, color: Theme.of(context).hintColor),
                        const SizedBox(width: 3),
                        Text(
                          news.displayTime,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        // Kategori
                        if (news.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              news.category!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Başlık
                    Text(
                      news.headline ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Özet / Facts özeti - Logo hizasında
                    if (news.facts != null && news.facts!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        news.facts!
                            .where((f) => f.key != null && f.value != null)
                            .take(2)
                            .map((f) => '${f.key}: ${f.value}')
                            .join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
}
