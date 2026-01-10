import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/news_item.dart';
import '../services/api_service.dart';
import '../widgets/stock_chart_widget.dart';
import '../widgets/ticker_logo.dart';
import 'package:provider/provider.dart';
import '../services/favorites_service.dart';
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
  
  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  static const Color positiveGreen = Color(0xFF10B981);
  static const Color negativeRed = Color(0xFFEF4444);
  
  static const String baseUrl = 'http://91.132.49.137:5296';
  
  List<NewsItem> _news = [];
  bool _isLoading = true;
  String? _error;
  
  // Price data
  Map<String, dynamic> _priceData = {};
  bool _isPriceLoading = true;
  
  // Chart period change
  double _chartChangePercent = 0.0;
  String _selectedPeriod = '1G';

  @override
  void initState() {
    super.initState();
    _loadNews();
    _loadPriceData();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final news = await _apiService.getNewsByTicker(widget.ticker, pageSize: 100);
      if (mounted) {
        setState(() {
          _news = news;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPriceData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/Prices/ticker/${widget.ticker}'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _priceData = data['extraElements'] ?? {};
            _isPriceLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPriceLoading = false);
      }
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '-';
    final num = (value is int) ? value.toDouble() : value as double;
    if (num >= 1e12) return '${(num / 1e12).toStringAsFixed(2)} Trilyon ₺';
    if (num >= 1e9) return '${(num / 1e9).toStringAsFixed(2)} Milyar ₺';
    if (num >= 1e6) return '${(num / 1e6).toStringAsFixed(2)} Milyon ₺';
    if (num >= 1e3) return '${(num / 1e3).toStringAsFixed(2)} Bin ₺';
    return '${num.toStringAsFixed(2)} ₺';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = _priceData['Last'] ?? 0.0;
    final change = _priceData['DailyChangePercent'] ?? 0.0;
    final isPositive = change > 0;
    final isNegative = change < 0;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            TickerLogo(ticker: widget.ticker, size: 32, borderRadius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ticker,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                  ),
                  Text(
                    widget.companyName,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<FavoritesService>(
            builder: (context, favoritesService, child) {
              final isFavorite = favoritesService.isFavorite(widget.ticker);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : (isDark ? Colors.white : primaryDark),
                  size: 24,
                ),
                onPressed: () {
                  favoritesService.toggleFavorite(widget.ticker);
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: isDark ? Colors.white : primaryDark, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadNews(), _loadPriceData()]);
        },
        color: isDark ? Colors.white : primaryDark,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CARİ FİYAT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _selectedPeriod,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _isPriceLoading ? '...' : '₺${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : primaryDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Builder(
                          builder: (context) {
                            final displayChange = _chartChangePercent != 0.0 ? _chartChangePercent : change;
                            final isPos = displayChange > 0;
                            final isNeg = displayChange < 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPos ? positiveGreen.withValues(alpha: 0.1) : (isNeg ? negativeRed.withValues(alpha: 0.1) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isPriceLoading ? '-' : '${isPos ? '+' : ''}${displayChange.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isPos ? positiveGreen : (isNeg ? negativeRed : Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chart
              StockChartWidget(
                ticker: widget.ticker,
                defaultPeriod: '1G',
                currentPrice: (_priceData['Last'] as num?)?.toDouble(),
                onPeriodChanged: (changePercent, period) {
                  setState(() {
                    // 1G için DailyChangePercent kullan (Prices API'den), diğerleri için chart hesaplaması
                    if (period == '1G') {
                      _chartChangePercent = (_priceData['DailyChangePercent'] as num?)?.toDouble() ?? 0.0;
                    } else {
                      _chartChangePercent = changePercent;
                    }
                    _selectedPeriod = period;
                  });
                },
              ),

              // Volume & Market Value
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfoBox('HACİM', _formatNumber(_priceData['TotalTurnover']), isDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoBox('PİYASA DEĞERİ', _formatNumber(_priceData['MarketValue']), isDark),
                    ),
                  ],
                ),
              ),

              // KAP Bildirimleri Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KAP Bildirimleri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : primaryDark,
                      ),
                    ),
                    if (_news.length > 5)
                      Text(
                        'Tümünü Gör',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),

              // News List
              _buildNewsList(isDark),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, bool isDark) {
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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildNewsList(bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_news.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Henüz bildirim yok',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _news.length > 10 ? 10 : _news.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        final news = _news[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewsDetailScreen(news: news)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kapRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        news.category ?? 'BİLDİRİM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kapRed,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${news.publishedAt?.date ?? ''}, ${news.displayTime}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  news.headline ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : primaryDark,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyInfo(bool isDark) {
    final sector = _priceData['Sector'] ?? 'Borsa İstanbul';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: isDark ? Colors.white : primaryDark),
              const SizedBox(width: 8),
              Text(
                'ŞİRKET KÜNYESİ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : primaryDark,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Sektör', sector.toString(), isDark),
          const SizedBox(height: 12),
          _buildInfoRow('Endeks', 'BIST 100, BIST 30', isDark),
          const SizedBox(height: 12),
          _buildInfoRow('Halka Açıklık', '%${(_priceData['FreeFloatRate'] ?? 0).toStringAsFixed(2)}', isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
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
