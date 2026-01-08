import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // Bu kısımda sistem temasını kestirmek zor olduğu için 
      // varsayılan olarak false veya main.dart'ta kontrol edilebilir.
      // Ancak basitlik adına sistem ise false varsayıyoruz veya UI'da kontrol ediyoruz.
      return false; 
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey);
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
    notifyListeners();
  }

  // Light Theme Definition
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A237E), // Indigo
      brightness: Brightness.light,
      surface: const Color(0xFFF5F7FA), // Açık gri-mavi arka plan
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A237E),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A237E),
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFF263238)),
      titleMedium: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
    ),
  );

  // Dark Theme Definition
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C6BC0), // Daha açık indigo
      brightness: Brightness.dark,
      surface: const Color(0xFF121212), // Koyu arka plan
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white10),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: const Color(0xFF5C6BC0),
      unselectedItemColor: Colors.grey.shade600,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      titleMedium: TextStyle(color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFE0E0E0),
    ),
  );
}
