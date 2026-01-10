import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kap_mobil/providers/theme_provider.dart';
import 'package:kap_mobil/services/favorites_service.dart';
import 'package:kap_mobil/services/saved_news_service.dart';
import 'package:kap_mobil/screens/news_screen.dart';
import 'package:kap_mobil/screens/stocks_screen.dart';
import 'package:kap_mobil/screens/saved_news_screen.dart';
import 'package:kap_mobil/screens/settings_screen.dart';
import 'package:kap_mobil/services/notification_service.dart';
import 'package:kap_mobil/services/user_service.dart';
import 'package:kap_mobil/screens/welcome_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesService()),
        ChangeNotifierProvider(create: (_) => SavedNewsService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => UserService()),
      ],
      child: const KapMobilApp(),
    ),
  );
}

class KapMobilApp extends StatelessWidget {
  const KapMobilApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'KAP Mobil',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      home: Consumer<UserService>(
        builder: (context, userService, child) {
          if (!userService.isInitialized) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return userService.hasName ? const MainScreen() : const WelcomeScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const NewsScreen(),
    const StocksScreen(),
    const SavedNewsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChange(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const BouncingScrollPhysics(), // Allows sliding between pages
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.article_outlined, Icons.article, 'Haberler', isDark),
                _buildNavItem(1, Icons.show_chart_rounded, Icons.show_chart_rounded, 'Hisseler', isDark),
                _buildNavItem(2, Icons.bookmark_border, Icons.bookmark, 'Kaydedilenler', isDark),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'Ayarlar', isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    // Selected color: white in dark mode, black in light mode
    final selectedColor = isDark ? Colors.white : Colors.black;
    
    return GestureDetector(
      onTap: () => _onTabChange(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? selectedColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

