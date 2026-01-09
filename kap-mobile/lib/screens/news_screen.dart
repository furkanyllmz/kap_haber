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
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _filterNews,
                      decoration: const InputDecoration(
                        hintText: 'Haber ara...',
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      'Akış',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isSearching ? Icons.close : Icons.search,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary
                      ),
                    ),
                    onPressed: () {
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
                   IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.notifications_outlined, size: 22, color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: _loadNews,
            color: Theme.of(context).colorScheme.primary,
            child: CustomScrollView(
              slivers: [
                // Highlight / Stories Section (Optional but requested "modern")
                SliverToBoxAdapter(
                  child: Container(
                    height: 110,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 6, // Mock stories count
                      itemBuilder: (context, index) {
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Colors.purpleAccent,
                                    ],
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.network(
                                      'https://picsum.photos/seed/story$index/200',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Öne Çıkan',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // News Feed
                _buildContentSliver(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Bağlantı hatası',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Yenile'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredNews.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'Haber bulunamadı',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
          childCount: _filteredNews.length,
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
