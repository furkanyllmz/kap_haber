import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/news_item.dart';
import '../providers/stock_provider.dart';
import '../services/api_service.dart';
import '../widgets/news_card.dart';
import '../widgets/stock_chart_widget.dart';
import '../widgets/ticker_logo.dart';
import 'news_detail_screen.dart';

class TickerNewsScreen extends StatefulWidget {
  final String ticker;
  final String companyName;

  const TickerNewsScreen({
    super.key,
    required this.ticker,
    required this.companyName,
  });

  @override
  State<TickerNewsScreen> createState() => _TickerNewsScreenState();
}

class _TickerNewsScreenState extends State<TickerNewsScreen> {
  final ApiService _apiService = ApiService();
  
  List<NewsItem> _news = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final news = await _apiService.getNewsByTicker(widget.ticker, pageSize: 100);
      setState(() {
        _news = news;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getTickerColor(String ticker) {
    // Sabit indigo rengi veya hash bazlı renk kullanılabilir
    return const Color(0xFF1A237E); 
  }

  Widget _buildLogo() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TickerLogo(
        ticker: widget.ticker,
        size: 64,
        borderRadius: 16,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, stockProvider, child) {
        final isFavorite = stockProvider.isFavorite(widget.ticker);
        final isNotificationEnabled = stockProvider.isNotificationEnabled(widget.ticker);

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
              widget.ticker,
              style: TextStyle(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isNotificationEnabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: isNotificationEnabled ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
                ),
                onPressed: () => stockProvider.toggleNotification(widget.ticker),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite ? Colors.amber : Theme.of(context).iconTheme.color,
                ),
                onPressed: () => stockProvider.toggleFavorite(widget.ticker),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                onPressed: _loadNews,
              ),
            ],
          ),
          body: Column(
            children: [
              // Şirket Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 16),
                      Text(
                        widget.companyName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!_isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_news.length} Bildirim',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                  ],
                ),
              ),

              // Grafik Alanı
              const SizedBox(height: 16),
              StockChartWidget(ticker: widget.ticker),

              const SizedBox(height: 16),

              // Haber listesi başlığı yok, direkt liste
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade200),
            const SizedBox(height: 16),
            Text(
              'Haberler yüklenemedi',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadNews,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_news.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Henüz haber yok',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _news.length,
        itemBuilder: (context, index) {
          final newsItem = _news[index];
          return NewsCard(
            news: newsItem,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewsDetailScreen(news: newsItem),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
