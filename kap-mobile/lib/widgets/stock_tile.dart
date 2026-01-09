import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ticker_logo.dart';

class StockTile extends StatelessWidget {
  final String ticker;
  final String name;
  final String? logoPath;
  final VoidCallback? onTap;
  final bool isFavorite;
  final bool isNotificationEnabled;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onNotificationToggle;

  const StockTile({
    super.key,
    required this.ticker,
    required this.name,
    this.logoPath,
    this.onTap,
    this.isFavorite = false,
    this.isNotificationEnabled = false,
    this.onFavoriteToggle,
    this.onNotificationToggle,
  });

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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticker,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: isNotificationEnabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: isNotificationEnabled ? theme.colorScheme.primary : theme.disabledColor,
                  onTap: onNotificationToggle,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite ? Colors.amber : theme.disabledColor,
                  onTap: onFavoriteToggle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return TickerLogo(
      ticker: ticker,
      size: 48,
      borderRadius: 12,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: color,
        ),
      ),
    );
  }
}
