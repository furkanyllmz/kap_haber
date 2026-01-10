import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kap_mobil/models/news_item.dart';
import 'package:kap_mobil/models/notification_item.dart';
import 'package:kap_mobil/services/api_service.dart';
import 'package:kap_mobil/services/favorites_service.dart';
import 'package:kap_mobil/services/notification_service.dart';
import 'package:kap_mobil/widgets/ticker_logo.dart';
import 'package:kap_mobil/screens/news_detail_screen.dart';
import 'package:kap_mobil/screens/notifications_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tickerScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();
  
  List<NewsItem> _news = [];
  List<NewsItem> _filteredNews = [];
  bool _isLoading = true;
  bool _isPaginationLoading = false;
  bool _isSearching = false;
  String? _error;
  int _selectedFilter = 0;
  
  // Pagination and filtering state
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;
  DateTime? _selectedDate;

  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  
  // Base URL for images
  static const String baseImageUrl = 'http://91.132.49.137:5296';

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_onScroll);
    _loadNews();
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onScroll);
    _mainScrollController.dispose();
    _tickerScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_mainScrollController.position.pixels >= _mainScrollController.position.maxScrollExtent - 200) {
      if (!_isPaginationLoading && _hasMore && !_isSearching && _selectedDate == null) {
        _loadMoreNews();
      }
    }
  }

  void _startTickerAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_tickerScrollController.hasClients) {
        _animateTicker();
      }
    });
  }

  void _animateTicker() async {
    while (mounted && _tickerScrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_tickerScrollController.hasClients) {
        final maxScroll = _tickerScrollController.position.maxScrollExtent;
        final currentScroll = _tickerScrollController.offset;
        if (currentScroll >= maxScroll) {
          _tickerScrollController.jumpTo(0);
        } else {
          _tickerScrollController.jumpTo(currentScroll + 1);
        }
      }
    }
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = _selectedDate == null;
    });

    try {
      List<NewsItem> news;
      if (_selectedDate != null) {
        // Format: YYYY-MM-DD
        final dateStr = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
        news = await _apiService.getNewsByDate(dateStr);
        _hasMore = false; // Date filtering doesn't support pagination on this endpoint
      } else {
        news = await _apiService.getAllNews(page: _currentPage, pageSize: _pageSize);
        if (news.length < _pageSize) {
          _hasMore = false;
        }
      }

      setState(() {
        _news = news;
        _applyFilters();
        _isLoading = false;
      });

      // Check news for favorites to trigger notifications
      if (mounted) {
        final favoritesService = Provider.of<FavoritesService>(context, listen: false);
        final notificationService = Provider.of<NotificationService>(context, listen: false);
        notificationService.checkNewsForFavorites(news, favoritesService.favorites);
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

  Future<void> _loadMoreNews() async {
    if (_isPaginationLoading || !_hasMore) return;

    setState(() {
      _isPaginationLoading = true;
    });

    try {
      _currentPage++;
      final news = await _apiService.getAllNews(page: _currentPage, pageSize: _pageSize);
      
      setState(() {
        if (news.isEmpty) {
          _hasMore = false;
        } else {
          _news.addAll(news);
          _applyFilters();
          if (news.length < _pageSize) {
            _hasMore = false;
          }
          
          // Check for favorited tickers in newly loaded news
          if (mounted) {
            final favoritesService = Provider.of<FavoritesService>(context, listen: false);
            final notificationService = Provider.of<NotificationService>(context, listen: false);
            notificationService.checkNewsForFavorites(news, favoritesService.favorites);
          }
        }
        _isPaginationLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPaginationLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = _news;
    
    // Filter by date
    // SKIP local date filtering if we fetched from server for a specific date
    // because server already filtered it and local parsing might fail formats
    if (_selectedDate != null && _news.isNotEmpty && _news.length < 100) {
      // If we have a huge list (e.g. from getAllNews), we might still want to filter
      // but if we just fetched by date, news.length will be exactly for that date.
      // Actually, it's safer to trust the API list if it was triggered by date selection.
    } else if (_selectedDate != null) {
      filtered = filtered.where((item) {
        if (item.publishedAt?.date == null) return false;
        try {
          final dateStr = item.publishedAt!.date!;
          // Support both DD.MM.YYYY and YYYY-MM-DD
          if (dateStr.contains('.')) {
            final parts = dateStr.split('.');
            if (parts.length == 3) {
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              return day == _selectedDate!.day && 
                     month == _selectedDate!.month && 
                     year == _selectedDate!.year;
            }
          } else if (dateStr.contains('-')) {
            final parts = dateStr.split('-');
            if (parts.length == 3) {
              final year = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final day = int.parse(parts[2]);
              return day == _selectedDate!.day && 
                     month == _selectedDate!.month && 
                     year == _selectedDate!.year;
            }
          }
        } catch (_) {}
        return false;
      }).toList();
    }
    
    // Filter by search query
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final ticker = item.displayTicker.toLowerCase();
        final headline = item.headline?.toLowerCase() ?? '';
        return ticker.contains(query) || headline.contains(query);
      }).toList();
    }
    
    // Sort logic for Featured News: Identify the most important news (max newsworthiness)
    // and put one of them (randomly picked if tie) at the very top.
    if (filtered.isNotEmpty) {
      double maxWorth = -1.0;
      for (var n in filtered) {
        if (n.newsworthiness > maxWorth) maxWorth = n.newsworthiness;
      }
      
      if (maxWorth > 0) {
        final topItems = filtered.where((n) => n.newsworthiness == maxWorth).toList();
        final featured = topItems[Random().nextInt(topItems.length)];
        
        // Move it to the top
        filtered.remove(featured); // remove first occurrence
        filtered.insert(0, featured);
      }
    }
    
    setState(() {
      _filteredNews = filtered;
    });

    // We no longer need to auto-page when date is selected because we fetch from server
    // But if not searching and no date filter, paginate as usual
    if (_filteredNews.isEmpty && _hasMore && !_isPaginationLoading && _selectedDate == null) {
      _loadMoreNews();
    }
  }

  void _filterNews(String query) {
    _applyFilters();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark 
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.white,
                  onPrimary: Colors.black,
                  surface: Color(0xFF1E1E1E),
                  onSurface: Colors.white,
                  secondary: Colors.white,
                  onSecondary: Colors.black,
                ),
                dialogBackgroundColor: const Color(0xFF1E1E1E),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            : ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: primaryDark,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: primaryDark,
                  secondary: primaryDark,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: primaryDark,
                  ),
                ),
              ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadNews(); // Reload news from server for the selected date
    }
  }

  String _getBannerUrl(NewsItem news, int index) {
    if (news.imageUrl != null && news.imageUrl!.isNotEmpty) {
      if (news.imageUrl!.startsWith('http')) {
        return news.imageUrl!;
      }
      return '$baseImageUrl${news.imageUrl!.startsWith('/') ? '' : '/'}${news.imageUrl}';
    }

    final category = news.category ?? 'Diğer';
    final imageIndex = (index % 6) + 1;
    
    // Map category to folder name
    String folderName;
    switch (category.toLowerCase()) {
      case 'sermaye':
        folderName = 'Sermaye';
        break;
      case 'spk':
        folderName = 'SPK';
        break;
      case 'sözleşme':
      case 'ihale':
        folderName = 'Sözleşme';
        break;
      case 'yatırım':
        folderName = 'Yatırım';
        break;
      case 'halka arz':
        folderName = 'Halka Arz';
        break;
      default:
        folderName = 'Diğer';
    }
    
    return '$baseImageUrl/banners/$folderName/${folderName.toLowerCase()}_$imageIndex.png';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: _buildNewsContent(isDark),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Row(
                children: [
                  _buildIconButton(
                    icon: _isSearching ? Icons.close : Icons.search,
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _applyFilters();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.calendar_today_outlined,
                    isDark: isDark,
                    onTap: () => _selectDate(context),
                    color: _selectedDate != null ? kapRed : null,
                  ),
                  const SizedBox(width: 8),
                  Consumer<NotificationService>(
                    builder: (context, service, child) {
                      return Stack(
                        children: [
                          _buildIconButton(
                            icon: Icons.notifications_outlined,
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                              );
                            },
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
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => _applyFilters(),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Haber veya hisse ara...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          if (_selectedDate != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = null;
                  _applyFilters();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close,
                      size: 14,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color != null ? color.withValues(alpha: 0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: color ?? (isDark ? Colors.white : primaryDark),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['Tümü', 'Borsa İstanbul', 'Şirketler'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(filters.length, (index) {
            final isSelected = _selectedFilter == index;
            return Padding(
              padding: EdgeInsets.only(right: index < filters.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryDark : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected ? null : Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    filters[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNewsTicker(bool isDark) {
    if (_news.isEmpty) return const SizedBox.shrink();
    
    final latestNews = _news.take(5).toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: kapRed.withValues(alpha: isDark ? 0.1 : 0.05),
        border: Border(
          bottom: BorderSide(color: kapRed.withValues(alpha: 0.1)),
        ),
      ),
      child: SingleChildScrollView(
        controller: _tickerScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: kapRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            ...latestNews.map((news) => Row(
              children: [
                Text(
                  '${news.displayTicker}: ${news.headline ?? ""}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('•', style: TextStyle(color: Colors.grey.shade400)),
                ),
              ],
            )),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsContent(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : primaryDark),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Haberler yüklenemedi', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadNews,
              style: ElevatedButton.styleFrom(backgroundColor: primaryDark, foregroundColor: Colors.white),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_filteredNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Haber bulunamadı', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: isDark ? Colors.white : primaryDark,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: ListView.builder(
        controller: _mainScrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _filteredNews.length + (_isPaginationLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredNews.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          final isHero = index == 0;
          return isHero 
              ? _buildHeroCard(_filteredNews[index], isDark, index)
              : _buildCompactCard(_filteredNews[index], isDark, index);
        },
      ),
    );
  }

  // Hero card with large image (first item)
  Widget _buildHeroCard(NewsItem news, bool isDark, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(news: news))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.network(
                    _getBannerUrl(news, index),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: primaryDark.withValues(alpha: 0.1),
                      child: Center(child: Icon(Icons.image, size: 48, color: Colors.grey.shade400)),
                    ),
                  ),
                  // Ticker badge overlay
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          TickerLogo(
                            ticker: news.displayTicker,
                            size: 24,
                            borderRadius: 6,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            news.displayTicker,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // "Featured" Badge overlay
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kapRed,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'ÖNE ÇIKAN',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                          ),
                        ],
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
                  Row(
                    children: [
                      Text(
                        (news.category ?? 'ÖZEL DURUM AÇIKLAMASI').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kapRed, letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      Text(
                        news.publishedAt?.time ?? '',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    news.headline ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.grey.shade800,
                      height: 1.3,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'FİNANSAL RAPOR',
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.w700, 
                          color: isDark ? Colors.white70 : primaryDark.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.share_outlined, size: 18, color: Colors.grey.shade400),
                      const SizedBox(width: 16),
                      Icon(Icons.bookmark_outline, size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact card with side image
  Widget _buildCompactCard(NewsItem news, bool isDark, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(news: news))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticker and time
                  Row(
                    children: [
                      TickerLogo(
                        ticker: news.displayTicker,
                        size: 28,
                        borderRadius: 6,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        news.displayTicker,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : primaryDark),
                      ),
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 6),
                      Text(
                        news.publishedAt?.time ?? '',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Headline
                  Text(
                    news.headline ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                      height: 1.35,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  // Category and actions
                  Row(
                    children: [
                      Text(
                        (news.category ?? 'GENEL').toUpperCase(),
                        style: TextStyle(
                          fontSize: 9, 
                          fontWeight: FontWeight.w700, 
                          color: isDark ? Colors.white70 : primaryDark.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _getBannerUrl(news, index),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 90,
                  height: 90,
                  color: primaryDark.withValues(alpha: 0.1),
                  child: Icon(Icons.image, color: Colors.grey.shade400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
