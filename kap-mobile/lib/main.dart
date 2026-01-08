import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/news_screen.dart';
import 'screens/stocks_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
              unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentIndex == 0 
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.article_outlined, 
                      color: _currentIndex == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor),
                  ),
                  label: 'Haberler',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                     padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentIndex == 1
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.show_chart_rounded, 
                      color: _currentIndex == 1 ? Theme.of(context).colorScheme.primary : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor),
                  ),
                  label: 'Hisseler',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                     padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentIndex == 2
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.settings_outlined, 
                      color: _currentIndex == 2 ? Theme.of(context).colorScheme.primary : Theme.of(context).bottomNavigationBarTheme.unselectedItemColor),
                  ),
                  label: 'Ayarlar',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
