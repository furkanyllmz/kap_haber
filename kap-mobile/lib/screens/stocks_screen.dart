import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/favorites_service.dart';
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
  bool _showFavorites = false; // Favori filtresi
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
    if (!mounted) return;
    
    final favoritesService = Provider.of<FavoritesService>(context, listen: false);
    
    setState(() {
      var tempStocks = _stocks;

      // 1. Favori filtresi
      if (_showFavorites) {
        tempStocks = tempStocks.where((stock) => favoritesService.isFavorite(stock['ticker'])).toList();
      }

      // 2. Metin araması
      if (query.isNotEmpty) {
        tempStocks = tempStocks.where((stock) {
          final ticker = stock['ticker'].toLowerCase();
          final name = stock['name'].toLowerCase();
          final searchLower = query.toLowerCase();
          return ticker.contains(searchLower) || name.contains(searchLower);
        }).toList();
      }
      
      _filteredStocks = tempStocks;
    });
  }
  
  // Favori listesi değiştiğinde listeyi güncellemek için
  void _refreshList() {
    _filterStocks(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    // Favori değişikliklerini dinle ve listeyi güncelle
    final favoritesService = Provider.of<FavoritesService>(context);
    // Bu yöntem build her tetiklendiğinde _refreshList'i dolaylı olarak çağırmamızı sağlar 
    // ancak sonsuz döngüye girmemek için dikkatli olmalıyız.
    // En iyisi Consumer kullanmak veya sadece filtreleme mantığında context.watch kullanmak.
    // Burada basitçe: _showFavorites true ise listeyi tekrar hesaplayalım.
    if (_showFavorites) {
        // Bu biraz riskli (setState içinde setState). 
        // Onun yerine aşağıda ListView.builder içinde where kontrolü yapmak daha safe,
        // ama arama ile birleştirmek için filtre fonksiyonu daha iyi.
        // Çözüm: filteredStocks'u build içinde hesaplamak.
    }

    // Modern yöntem: Listeyi build anında filtrele
    var displayStocks = _stocks;
    if (_showFavorites) {
       displayStocks = displayStocks.where((s) => favoritesService.isFavorite(s['ticker'])).toList();
    }
    if (_searchController.text.isNotEmpty) {
       final query = _searchController.text.toLowerCase();
       displayStocks = displayStocks.where((s) {
          return s['ticker'].toLowerCase().contains(query) || s['name'].toLowerCase().contains(query);
       }).toList();
    }
    
    // Header Stats
    final totalCount = _stocks.length;
    final displayCount = displayStocks.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                      // Tümü / Favoriler Toggle
                       Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            _buildToggleButton('Tümü', !_showFavorites),
                            _buildToggleButton('Favoriler', _showFavorites),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Arama
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                       setState(() {}); // Sadece re-build tetikle, filtreleme build içinde
                    },
                    style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Hisse kodu veya şirket ara...',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color == Colors.white 
                            ? Colors.grey.shade100 
                            : Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
            
            // Stats & List Header
            Padding(
               padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(
                      _showFavorites ? 'FAVORİ HİSSELER' : 'TÜM HİSSELER ($totalCount)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                   ),
                   Text(
                      '$displayCount gösteriliyor',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).hintColor,
                      ),
                   ),
                 ],
               ),
            ),

            // Hisse listesi
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))
                  : displayStocks.isEmpty 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showFavorites ? Icons.favorite_border : Icons.search_off, 
                                size: 64, 
                                color: Colors.grey.shade300
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _showFavorites 
                                  ? 'Henüz favori hisseniz yok' 
                                  : 'Hisse bulunamadı',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      // Listeyi her seferinde yeniden oluşturmamak için key
                      key: ValueKey('$_showFavorites-${_searchController.text}'), 
                      itemCount: displayStocks.length,
                      itemBuilder: (context, index) {
                        final stock = displayStocks[index];
                        final isFavorite = favoritesService.isFavorite(stock['ticker']);
                        
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
                            // Favoriyse hafif renkli border (opsiyonel)
                            border: isFavorite && !_showFavorites
                                ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1)
                                : null,
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
                            trailing: IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Theme.of(context).hintColor.withValues(alpha: 0.3),
                              ),
                              onPressed: () => favoritesService.toggleFavorite(stock['ticker']),
                            ),
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
  
  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFavorites = text == 'Favoriler';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimary 
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
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
