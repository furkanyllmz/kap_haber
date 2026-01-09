import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_tile.dart';
import 'ticker_news_screen.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, stockProvider, child) {
        // Filter stocks based on search query
        var filteredStocks = stockProvider.stocks;
        if (_searchQuery.isNotEmpty) {
          filteredStocks = filteredStocks.where((stock) {
            final ticker = stock['ticker'].toLowerCase();
            final name = stock['name'].toLowerCase();
            final searchLower = _searchQuery.toLowerCase();
            return ticker.contains(searchLower) || name.contains(searchLower);
          }).toList();
        }

        // Get favorite stocks
        final favoriteStocks = filteredStocks
            .where((stock) => stockProvider.isFavorite(stock['ticker']))
            .toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Modern Header with Search and Tabs
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Hisseler',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Modern Arama Çubuğu
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Hisse kodu veya şirket ara...',
                          hintStyle: TextStyle(color: Theme.of(context).hintColor),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                          filled: true,
                          fillColor: Theme.of(context).cardTheme.color == Colors.white
                              ? Colors.grey.shade100
                              : Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(context).disabledColor,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                        tabs: const [
                          Tab(text: 'Tümü'),
                          Tab(text: 'Favoriler'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab View
                Expanded(
                  child: stockProvider.isLoading
                      ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStockList(context, filteredStocks, stockProvider),
                            _buildStockList(context, favoriteStocks, stockProvider, isFavoritesTab: true),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockList(
    BuildContext context,
    List<Map<String, dynamic>> stocks,
    StockProvider stockProvider, {
    bool isFavoritesTab = false,
  }) {
    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFavoritesTab ? Icons.star_border_rounded : Icons.search_off_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isFavoritesTab ? 'Favori hisseniz yok' : 'Sonuç bulunamadı',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final ticker = stock['ticker'];
        final isFavorite = stockProvider.isFavorite(ticker);
        final isNotificationEnabled = stockProvider.isNotificationEnabled(ticker);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: StockTile(
            ticker: ticker,
            name: stock['name'],
            logoPath: 'assets/logos/$ticker.svg',
            isFavorite: isFavorite,
            isNotificationEnabled: isNotificationEnabled,
            onFavoriteToggle: () => stockProvider.toggleFavorite(ticker),
            onNotificationToggle: () => stockProvider.toggleNotification(ticker),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TickerNewsScreen(
                    ticker: ticker,
                    companyName: stock['name'],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
