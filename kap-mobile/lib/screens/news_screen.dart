import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../services/api_service.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tickerScrollController = ScrollController();
  
  List<NewsItem> _news = [];
  List<NewsItem> _filteredNews = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  int _selectedFilter = 0;

  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  
  // Base URL for images
  static const String baseImageUrl = 'http://91.132.49.137:5296';

  @override
  void initState() {
    super.initState();
    _loadNews();
    _startTickerAnimation();
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
    });

    try {
      final news = await _apiService.getLatestNews(count: 50);
      setState(() {
        _news = news;
        _filteredNews = news;
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

  void _filterNews(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredNews = _news;
      } else {
        _filteredNews = _news.where((news) {
          final ticker = news.displayTicker.toLowerCase();
          final headline = news.headline?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return ticker.contains(searchLower) || headline.contains(searchLower);
        }).toList();
      }
    });
  }

  String _getBannerUrl(NewsItem news, int index) {
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F4F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildFilterChips(isDark),
            _buildNewsTicker(isDark),
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
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CANLI VERİ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kapRed,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'KAP ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : primaryDark,
                        ),
                      ),
                      Text(
                        'Akışı',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
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
                          _filterNews('');
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    children: [
                      _buildIconButton(
                        icon: Icons.notifications_outlined,
                        isDark: isDark,
                        onTap: () {},
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
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _filterNews,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Haber veya hisse ara...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white : primaryDark,
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['Tümü', 'Borsa İstanbul', 'Şirketler'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                    color: isSelected ? primaryDark : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
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
          valueColor: AlwaysStoppedAnimation<Color>(primaryDark),
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
        child: Text('Haber bulunamadı', style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: primaryDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredNews.length,
        itemBuilder: (context, index) {
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
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: primaryDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                news.displayTicker.substring(0, 1),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
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
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryDark.withValues(alpha: 0.6)),
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
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: primaryDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            news.displayTicker.substring(0, 1),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
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
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: primaryDark.withValues(alpha: 0.6)),
                      ),
                      const Spacer(),
                      Icon(Icons.share_outlined, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Icon(Icons.bookmark_outline, size: 16, color: Colors.grey.shade400),
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

  @override
  void dispose() {
    _searchController.dispose();
    _tickerScrollController.dispose();
    super.dispose();
  }
}
