import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/stock_tile.dart';
import 'ticker_news_screen.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  List<Map<String, dynamic>> _stocks = [];
  List<Map<String, dynamic>> _filteredStocks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

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
        return {
          'ticker': entry.key,
          'name': entry.value,
        };
      }).toList();
      
      // Alfabetik sırala
      stocks.sort((a, b) => a['ticker'].compareTo(b['ticker']));
      
      setState(() {
        _stocks = stocks;
        _filteredStocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterStocks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStocks = _stocks;
      } else {
        _filteredStocks = _stocks.where((stock) {
          final ticker = stock['ticker'].toLowerCase();
          final name = stock['name'].toLowerCase();
          final searchLower = query.toLowerCase();
          return ticker.contains(searchLower) || name.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredStocks.length} BIST',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Modern Arama Çubuğu
                  TextField(
                    controller: _searchController,
                    onChanged: _filterStocks,
                    style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Hisse kodu veya şirket ara...',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color == Colors.white 
                            ? Colors.grey.shade100 
                            : Colors.white.withValues(alpha: 0.05),
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
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            // Hisse listesi
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filteredStocks.length,
                      itemBuilder: (context, index) {
                        final stock = _filteredStocks[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: StockTile(
                            ticker: stock['ticker'],
                            name: stock['name'],
                            logoPath: 'assets/logos/${stock['ticker']}.svg',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TickerNewsScreen(
                                    ticker: stock['ticker'],
                                    companyName: stock['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
