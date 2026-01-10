import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  final Color primaryDark = const Color(0xFF002B3A);

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hakkımızda',
          style: TextStyle(
            color: isDark ? Colors.white : primaryDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Section
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      isDark ? 'assets/headerlogo_beyaz.png' : 'assets/headerlogo_beyaz.png', // Update if there's a dark logo
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'KAP Finans Haberleri',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Veri, Analiz ve Hız',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // AI Section
            _buildInfoCard(
              context,
              isDark,
              icon: Icons.auto_awesome_outlined,
              title: 'Yapay Zeka Destekli',
              description: 'Uygulamamızdaki tüm haber başlıkları ve özetleri, gelişmiş yapay zeka (LLM) teknolojileri kullanılarak analiz edilir. Karmaşık finansal raporlar, sizin için en anlaşılır ve hızlı şekilde özetlenir.',
              iconColor: Colors.purple.shade400,
            ),
            const SizedBox(height: 16),

            // Web/Social Section
            _buildInfoCard(
              context,
              isDark,
              icon: Icons.language_outlined,
              title: 'Dijital Varlığımız',
              description: 'KAP Haber deneyimini web üzerinden de yaşayabilir veya bizi sosyal medyada takip ederek anlık bildirimlere ulaşabilirsiniz.',
              iconColor: Colors.blue.shade400,
              footer: Row(
                children: [
                  _buildSocialButton(
                    label: 'kaphaber.com',
                    icon: Icons.public,
                    onTap: () => _launchUrl('https://kaphaber.com'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildSocialButton(
                    label: 'X Platformu',
                    icon: Icons.close, // Using close as a placeholder for X
                    onTap: () => _launchUrl('https://x.com/kap_haberlerii'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mission Section
            _buildInfoCard(
              context,
              isDark,
              icon: Icons.speed_outlined,
              title: 'Misyonumuz',
              description: 'Kamuoyu Aydınlatma Platformu\'ndaki verileri şeffaf, hızlı ve herkesin anlayabileceği bir dille sunarak yatırımcıların doğru kararlar almasına yardımcı olmak.',
              iconColor: Colors.orange.shade400,
            ),
            
            const SizedBox(height: 48),
            Center(
              child: Text(
                '© 2026 KAP Haber. Tüm hakları saklıdır.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 16),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.white70 : primaryDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
