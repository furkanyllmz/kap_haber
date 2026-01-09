import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'providers/theme_provider.dart';
import 'services/favorites_service.dart';
import 'screens/news_screen.dart';
import 'screens/stocks_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesService()),
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
      home: const MainScreen(),
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

  final List<Widget> _screens = [
    const NewsScreen(),
    const StocksScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // İnceltilmiş padding
            child: GNav(
              rippleColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              gap: 8, // Icon ve Text yan yana, arada 8px boşluk
              activeColor: Theme.of(context).colorScheme.primary,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Tab iç padding
              duration: const Duration(milliseconds: 300),
              tabBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              color: Theme.of(context).hintColor, // Seçili olmayan icon rengi
              textStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
              tabs: const [
                GButton(
                  icon: Icons.article_outlined,
                  text: 'Haberler',
                ),
                GButton(
                  icon: Icons.show_chart_rounded,
                  text: 'Hisseler',
                ),
                GButton(
                  icon: Icons.settings_outlined,
                  text: 'Ayarlar',
                ),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
