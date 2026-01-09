import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/favorites_service.dart';
import 'ticker_news_screen.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  List<Map<String, dynamic>> _stocks = [];
  bool _isLoading = true;
  int _selectedFilter = 0; // 0: Tümü, 1: Takip Ettiklerim, 2: BIST 100, 3: Yükselenler
  final TextEditingController _searchController = TextEditingController();

  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  static const Color positiveGreen = Color(0xFF10B981);
  static const Color negativeRed = Color(0xFFEF4444);

  // Mock prices (would come from API in real app)
  final Map<String, Map<String, dynamic>> _mockPrices = {
    'ASELS': {'price': 54.20, 'change': 2.45},
    'EREGL': {'price': 41.12, 'change': -1.10},
    'THYAO': {'price': 265.50, 'change': 0.85},
    'KCHOL': {'price': 142.00, 'change': -0.30},
    'SISE': {'price': 48.74, 'change': 1.12},
    'TUPRS': {'price': 164.20, 'change': 3.20},
    'AKBNK': {'price': 52.80, 'change': 1.45},
    'GARAN': {'price': 98.50, 'change': -0.65},
    'SAHOL': {'price': 78.30, 'change': 0.92},
    'BIMAS': {'price': 445.00, 'change': 2.10},
  };

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/stocks.json');
      final Map<String, dynamic> stocksMap = json.decode(jsonString);
      
      final stocks = stocksMap.entries.map((entry) {
        final priceData = _mockPrices[entry.key] ?? {'price': 0.0, 'change': 0.0};
        return {
          'ticker': entry.key,
          'name': entry.value,
          'price': priceData['price'],
          'change': priceData['change'],
        };
      }).toList();
      
      stocks.sort((a, b) => a['ticker'].compareTo(b['ticker']));
      
      setState(() {
        _stocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStocks {
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);
    var result = _stocks;

    // Apply filter
    switch (_selectedFilter) {
      case 1: // Takip Ettiklerim
        result = result.where((s) => favoritesService.isFavorite(s['ticker'])).toList();
        break;
      case 2: // BIST 100 (mock - just take first 100)
        result = result.take(100).toList();
        break;
      case 3: // Yükselenler
        result = result.where((s) => (s['change'] ?? 0) > 0).toList();
        break;
    }

    // Apply search
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      result = result.where((s) {
        return s['ticker'].toLowerCase().contains(query) || 
               s['name'].toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayStocks = _filteredStocks;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildSearchBar(isDark),
            _buildFilterTabs(isDark),
            Expanded(
              child: _buildStocksList(isDark, displayStocks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Row(
        children: [
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          // Title
          Text(
            'KAP Piyasalar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : primaryDark,
            ),
          ),
          const Spacer(),
          // Notification Icon
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: isDark ? Colors.white : primaryDark,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kapRed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Şirket veya Sembol Ara...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final filters = ['Tümü', 'Takip Ettiklerim', 'BIST 100', 'Yükselenler'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(filters.length, (index) {
            final isSelected = _selectedFilter == index;
            return Padding(
              padding: EdgeInsets.only(right: index < filters.length - 1 ? 12 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Text(
                  filters[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected 
                        ? (isDark ? Colors.tealAccent : primaryDark) 
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStocksList(bool isDark, List<Map<String, dynamic>> stocks) {
    final favoritesService = Provider.of<FavoritesService>(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryDark),
        ),
      );
    }

    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == 1 ? Icons.favorite_border : Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 1 ? 'Henüz takip ettiğiniz hisse yok' : 'Hisse bulunamadı',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final isFavorite = favoritesService.isFavorite(stock['ticker']);
        final change = stock['change'] ?? 0.0;
        final isPositive = change > 0;
        final isNegative = change < 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TickerNewsScreen(
                  ticker: stock['ticker'],
                  companyName: stock['name'],
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Company Logo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      'https://kaphaber.com.tr/logos/${stock['ticker']}.svg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          stock['ticker'].substring(0, stock['ticker'].length > 2 ? 2 : stock['ticker'].length),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Company Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock['ticker'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock['name'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Price and Change
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(stock['price'] ?? 0.0).toStringAsFixed(2)} TL',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? positiveGreen : (isNegative ? negativeRed : Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Favorite Button
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => favoritesService.toggleFavorite(stock['ticker']),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isFavorite ? kapRed : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
