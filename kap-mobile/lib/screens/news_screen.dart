import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../services/api_service.dart';
import '../widgets/news_card.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<NewsItem> _news = [];
  List<NewsItem> _filteredNews = [];
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
                        'KAP Mobil',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                          onPressed: _loadNews,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Modern Arama Çubuğu
                  TextField(
                    controller: _searchController,
                    onChanged: _filterNews,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Haber veya hisse ara...',
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
            
            // Son Gelişmeler başlığı
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Text(
                    'SON GELİŞMELER',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoading)
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_filteredNews.length} haber',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Haber listesi
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 32, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'Haberler yüklenemedi',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadNews,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Haber bulunamadı',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).cardTheme.color,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: _filteredNews.length,
        itemBuilder: (context, index) {
          final newsItem = _filteredNews[index];
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
