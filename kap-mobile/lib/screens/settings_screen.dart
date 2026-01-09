import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ayarlar',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Profil Kartı (Opsiyonel - Gelecek için placeholder)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Misafir Kullanıcı',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'KAP Mobil Ücretsiz Sürüm',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              Text(
                'GENEL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).hintColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Bildirimler',
                      trailing: Switch.adaptive(
                        value: _notificationsEnabled,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                      ),
                    ),

                      _buildSettingsTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Karanlık Mod',
                        trailing: Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return Switch.adaptive(
                              value: themeProvider.isDarkMode,
                              onChanged: (val) {
                                themeProvider.toggleTheme(val);
                                // iOS stili geçiş efekti için opsiyonel:
                                // SystemChrome.setSystemUIOverlayStyle(...)
                              },
                              activeColor: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Text(
                'UYGULAMA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).hintColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.info_outline,
                      title: 'Hakkında',
                      onTap: () {},
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
                    ),
                    _buildSettingsTile(
                      icon: Icons.star_outline,
                      title: 'Uygulamayı Değerlendir',
                      onTap: () {},
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
                    ),
                    _buildSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Gizlilik Politikası',
                      onTap: () {},
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Center(
                child: Text(
                  'Versiyon 1.0.0 (Beta)',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
    );
  }
}
