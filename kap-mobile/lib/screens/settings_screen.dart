import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/saved_news_service.dart';
import '../widgets/ticker_logo.dart';
import 'news_detail_screen.dart';
import '../services/user_service.dart';
import 'about_us_screen.dart';
import 'privacy_policy_screen.dart';
import '../widgets/avatar_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  // KAP Colors
  static const Color kapRed = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFF002B3A);
  static const Color accentColor = Color(0xFF002B3A); // Same as primaryDark

  void _showAvatarPicker(BuildContext context, UserService userService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profil Fotoğrafı Seç',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: 16,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        userService.updateAvatar(index);
                        Navigator.pop(context);
                      },
                      child: Stack(
                        children: [
                          AvatarWidget(index: index, size: 80, showBorder: false),
                          if (userService.avatarIndex == index)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: primaryDark.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showGenderPicker(BuildContext context, UserService userService, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Cinsiyet Seçin',
          style: TextStyle(color: isDark ? Colors.white : primaryDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.male, color: isDark ? Colors.white : primaryDark),
              title: Text('Erkek', style: TextStyle(color: isDark ? Colors.white : primaryDark)),
              trailing: userService.gender == 'male' ? Icon(Icons.check, color: isDark ? Colors.white : primaryDark) : null,
              onTap: () {
                userService.updateGender('male');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.female, color: isDark ? Colors.white : primaryDark),
              title: Text('Kadın', style: TextStyle(color: isDark ? Colors.white : primaryDark)),
              trailing: userService.gender == 'female' ? Icon(Icons.check, color: isDark ? Colors.white : primaryDark) : null,
              onTap: () {
                userService.updateGender('female');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Ayarlar',
          style: TextStyle(
            color: isDark ? Colors.white : primaryDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil Kartı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Consumer<UserService>(
                    builder: (context, userService, child) {
                      return GestureDetector(
                        onTap: () => _showAvatarPicker(context, userService),
                        child: Stack(
                          children: [
                            AvatarWidget(index: userService.avatarIndex, size: 64),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white : primaryDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 1.5),
                                ),
                                child: Icon(Icons.edit, color: isDark ? Colors.black : Colors.white, size: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<UserService>(
                          builder: (context, userService, child) {
                            return Text(
                              userService.userName.isNotEmpty ? userService.userName : 'KAP Kullanıcısı',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : primaryDark,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Consumer<UserService>(
                          builder: (context, userService, child) {
                            return Text(
                              userService.gender == 'male' ? 'Erkek' : 'Kadın',
                              style: TextStyle(
                                fontSize: 14,
                                color: (isDark ? Colors.white : primaryDark).withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            _buildSectionTitle('GENEL AYARLAR', isDark),
            const SizedBox(height: 8),
            
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Bildirimler',
                    isDark: isDark,
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      activeColor: isDark ? Colors.white : primaryDark,
                      activeTrackColor: isDark ? Colors.white.withOpacity(0.3) : primaryDark.withOpacity(0.3),
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return isDark ? primaryDark : Colors.white;
                        }
                        return null;
                      }),
                      onChanged: (value) => setState(() => _notificationsEnabled = value),
                    ),
                  ),
                  _buildDivider(isDark),
                  Consumer<UserService>(
                    builder: (context, userService, child) {
                      return _buildSettingsTile(
                        icon: Icons.person_outline,
                        title: 'Cinsiyet',
                        isDark: isDark,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userService.gender == 'male' ? 'Erkek' : 'Kadın',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                          ],
                        ),
                        onTap: () => _showGenderPicker(context, userService, isDark),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return Column(
                        children: [
                          _buildSettingsTile(
                            icon: Icons.brightness_4_outlined,
                            title: 'Tema Ayarları',
                            isDark: isDark,
                            trailing: Text(
                              themeProvider.themeMode == ThemeMode.system ? 'Sistem' : (themeProvider.themeMode == ThemeMode.dark ? 'Karanlık' : 'Aydınlık'),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(60, 0, 16, 12),
                            child: Row(
                              children: [
                                _buildThemeOption('Sistem', ThemeMode.system, themeProvider, isDark),
                                const SizedBox(width: 8),
                                _buildThemeOption('Aydınlık', ThemeMode.light, themeProvider, isDark),
                                const SizedBox(width: 8),
                                _buildThemeOption('Karanlık', ThemeMode.dark, themeProvider, isDark),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    icon: Icons.bookmark_outline,
                    title: 'Kaydedilen Haberler',
                    isDark: isDark,
                    onTap: () => _showSavedNews(context, isDark),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('UYGULAMA HAKKINDA', isDark),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'Hakkımızda',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                      );
                    },
                    trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    icon: Icons.star_outline,
                    title: 'Uygulamayı Değerlendir',
                    isDark: isDark,
                    onTap: () {},
                    trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Gizlilik Politikası',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                      );
                    },
                    trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            Center(
              child: Text(
                'KAP Finans Haberleri v1.1.0',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 60),
      height: 1,
      color: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, ThemeProvider provider, bool isDark) {
    final isSelected = provider.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white : primaryDark) : (isDark ? Colors.white10 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? (isDark ? Colors.white : primaryDark) : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white60 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : primaryDark).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDark ? Colors.white : primaryDark, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : primaryDark,
        ),
      ),
      trailing: trailing,
    );
  }

  void _showSavedNews(BuildContext context, bool isDark) {
    final savedNewsService = Provider.of<SavedNewsService>(context, listen: false);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF2F4F7),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : primaryDark, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Kaydedilen Haberler',
              style: TextStyle(
                color: isDark ? Colors.white : primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          body: Consumer<SavedNewsService>(
            builder: (context, service, child) {
              if (service.savedNews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz kaydedilen haber yok',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Haberleri kaydetmek için\nyer imi ikonuna dokunun',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: service.savedNews.length,
                itemBuilder: (context, index) {
                  final news = service.savedNews[index];
                  return Dismissible(
                    key: Key(news.id ?? ''),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      service.removeNews(news.id ?? '');
                    },
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewsDetailScreen(news: news),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            TickerLogo(
                              ticker: news.displayTicker,
                              size: 40,
                              borderRadius: 8,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    news.displayTicker,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    news.headline ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
