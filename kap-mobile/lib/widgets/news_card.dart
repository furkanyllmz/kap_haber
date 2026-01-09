import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Logo, Ticker, Time
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TickerLogo(
                  ticker: news.displayTicker,
                  size: 40,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.displayTicker,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        news.displayTime,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_horiz,
                  color: Theme.of(context).disabledColor,
                ),
              ],
            ),
          ),

          // Main Image
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    news.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Theme.of(context).highlightColor.withOpacity(0.1),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(context).highlightColor.withOpacity(0.1),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                if (news.category != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        backdropFilter: const ColorFilter.mode(Colors.black, BlendMode.srcOver),
                      ),
                      child: Text(
                        news.category!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    news.headline ?? 'Haber Başlığı Yok',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (news.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    news.summary,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.favorite_border_rounded,
                  label: 'Beğen',
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Yorum Yap',
                  onTap: () {},
                ),
                const Spacer(),
                _ActionButton(
                  icon: Icons.share_outlined,
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.bookmark_border_rounded,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
