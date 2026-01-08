import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ticker_logo.dart';

class StockTile extends StatelessWidget {
  final String ticker;
  final String name;
  final String? logoPath;
  final VoidCallback? onTap;

  const StockTile({
    super.key,
    required this.ticker,
    required this.name,
    this.logoPath,
    this.onTap,
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildLogo(),
      title: Text(
        ticker,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        name,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).dividerColor),
    );
  }

  Widget _buildLogo() {
    return TickerLogo(
      ticker: ticker,
      size: 44,
      borderRadius: 8,
    );
  }


}
