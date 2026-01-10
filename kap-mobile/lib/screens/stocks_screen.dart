import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:kap_mobil/services/favorites_service.dart';
import 'package:kap_mobil/services/notification_service.dart';
import 'package:kap_mobil/widgets/ticker_logo.dart';
import 'package:kap_mobil/screens/ticker_news_screen.dart';
import 'package:kap_mobil/screens/notifications_screen.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  // Static cache - persists across widget rebuilds
  static List<Map<String, dynamic>> _stocksCache = [];
  static Map<String, Map<String, dynamic>> _priceCache = {};
  static bool _isDataLoaded = false;
  
  List<Map<String, dynamic>> _stocks = [];
  Map<String, Map<String, dynamic>> _priceData = {};
  bool _isLoading = true;
  bool _isPricesLoading = false;
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();

  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  static const Color positiveGreen = Color(0xFF10B981);
  static const Color negativeRed = Color(0xFFEF4444);
  
  // API Base URL
  static const String baseUrl = 'http://91.132.49.137:5296';

  @override
  void initState() {
    super.initState();
    // Use cache if available
    if (_isDataLoaded && _stocksCache.isNotEmpty) {
      _stocks = _stocksCache;
      _priceData = _priceCache;
      _isLoading = false;
    } else {
      _loadStocks();
    }
  }

  Future<void> _loadStocks() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/stocks.json');
      final Map<String, dynamic> stocksMap = json.decode(jsonString);
      
      final stocks = stocksMap.entries.map((entry) {
        return {
          'ticker': entry.key,
          'name': entry.value,
        };
      }).toList();
      
      stocks.sort((a, b) => a['ticker'].compareTo(b['ticker']));
      
      setState(() {
        _stocks = stocks;
        _stocksCache = stocks; // Cache it
        _isLoading = false;
      });
      
      // Load prices only if not cached
      if (_priceCache.isEmpty) {
        _loadAllPrices();
      } else {
        _priceData = _priceCache;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAllPrices() async {
    setState(() => _isPricesLoading = true);
    
    try {
      // Fetch all prices at once
      final response = await http.get(
        Uri.parse('$baseUrl/api/Prices'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> allPrices = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            for (var item in allPrices) {
              final ticker = item['ticker'] ?? '';
              final extra = item['extraElements'] ?? {};
              if (ticker.isNotEmpty) {
                _priceData[ticker] = {
                  'price': (extra['Last'] ?? extra['last'] ?? 0.0).toDouble(),
                  'change': (extra['DailyChangePercent'] ?? extra['dailyChangePercent'] ?? 0.0).toDouble(),
                };
              }
            }
            _isPricesLoading = false;
          });
        }
        print('📊 Loaded ${allPrices.length} prices at once');
        
        // Update cache
        _priceCache = Map.from(_priceData);
        _isDataLoaded = true;
      }
    } catch (e) {
      print('Error loading prices: $e');
      if (mounted) {
        setState(() => _isPricesLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStocks {
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);
    var result = _stocks;

    switch (_selectedFilter) {
      case 1: // Takip Ettiklerim
        result = result.where((s) => favoritesService.isFavorite(s['ticker'])).toList();
        break;
      case 2: // Yükselenler
        result = result.where((s) {
          final priceInfo = _priceData[s['ticker']];
          return (priceInfo?['change'] ?? 0) > 0;
        }).toList();
        break;
    }

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
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F7),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo (Cropped to show wide part only)
          SizedBox(
            height: 35,
            width: 150,
            child: ClipRect(
              child: OverflowBox(
                minHeight: 100,
                maxHeight: 250,
                alignment: Alignment.center,
                child: Image.asset(
                  isDark ? 'assets/headerlogo_beyaz.png' : 'assets/headerlogo.png',
                  fit: BoxFit.fitHeight,
                ),
              ),
            ),
          ),
          // Notification Icon
          Consumer<NotificationService>(
            builder: (context, service, child) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: isDark ? Colors.white : primaryDark,
                      ),
                    ),
                    if (service.unreadCount > 0)
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
                              color: isDark ? const Color(0xFF121212) : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF121212) : Colors.white,
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
          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final filters = ['Tümü', 'Takip Ettiklerim', 'Yükselenler'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.transparent,
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
                        ? (isDark ? Colors.white : primaryDark) 
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
          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : primaryDark),
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

    return RefreshIndicator(
      onRefresh: () async {
        // Force reload prices on pull-to-refresh
        await _loadAllPrices();
      },
      color: isDark ? Colors.white : primaryDark,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: stocks.length,
        itemBuilder: (context, index) {
        final stock = stocks[index];
        final ticker = stock['ticker'] as String;
        final isFavorite = favoritesService.isFavorite(ticker);
        final priceInfo = _priceData[ticker];
        final price = priceInfo?['price'] ?? 0.0;
        final change = priceInfo?['change'] ?? 0.0;
        final isPositive = change > 0;
        final isNegative = change < 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TickerNewsScreen(
                  ticker: ticker,
                  companyName: stock['name'],
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                TickerLogo(
                  ticker: ticker,
                  size: 44,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                
                // Company Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticker,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock['name'] ?? '',
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
                      price > 0 ? '${price.toStringAsFixed(2)} TL' : '-',
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
                          price > 0 
                              ? '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%'
                              : '-',
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
                  onTap: () => favoritesService.toggleFavorite(ticker),
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
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
