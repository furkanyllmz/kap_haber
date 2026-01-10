import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final Color primaryDark = const Color(0xFF002B3A);

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
          'Gizlilik Politikası',
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
            // Yasal Uyarı Section - Most Important
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(isDark ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'ÖNEMLİ YASAL UYARI',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'KAP Finans Haberleri uygulamasında sunulan her türlü içerik, analiz, haber ve görsel; yalnızca bilgilendirme amaçlıdır. Burada yer alan bilgiler KESİNLİKLE YATIRIM TAVSİYESİ DEĞİLDİR (YTD).',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yatırım kararlarınızı vermeden önce mutlaka lisanslı bir yatırım danışmanı veya yetkili mercilerle görüşünüz. Uygulamamızda yer alan verilerin kullanımından doğabilecek maddi/manevi zararlardan KAP Haber sorumlu tutulamaz.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              isDark,
              title: '1. Veri Sorumlusu',
              content: 'KAP Haber ("Uygulama"), kullanıcı deneyimini iyileştirmek ve kişiselleştirilmiş hizmet sunmak amacıyla bazı temel verileri işlemektedir.',
            ),
            
            _buildSection(
              isDark,
              title: '2. Toplanan Veriler',
              content: 'Uygulamayı kullandığınızda aşağıdaki veriler cihazınızda veya yerel depolama birimlerinde saklanabilir:\n\n• Ad Soyad (Profil kişiselleştirmesi için)\n• Cinsiyet (İstatistiksel ve varsayılan ayarlar için)\n• Kaydedilen Haberler (Kendi isteğinizle sakladığınız veriler)\n• Uygulama Tercihleri (Tema ve bildirim ayarları)',
            ),

            _buildSection(
              isDark,
              title: '3. Verilerin Kullanım Amacı',
              content: 'Toplanan veriler yalnızca uygulama içi deneyimi optimize etmek, size özel bildirimler sunmak ve ayarlarınızı kalıcı kılmak amacıyla kullanılır. Verileriniz üçüncü şahıslarla ticari amaçla paylaşılmaz.',
            ),

            _buildSection(
              isDark,
              title: '4. Güvenlik',
              content: 'Verilerinizin güvenliği bizim için önemlidir. Bilgileriniz endüstri standartlarına uygun şekilde korunmaktadır. Ancak internet üzerinden iletilen hiçbir yöntemin %100 güvenli olmadığını hatırlatmak isteriz.',
            ),

            _buildSection(
              isDark,
              title: '5. Değişiklikler',
              content: 'Bu gizlilik politikası zaman zaman güncellenebilir. Değişiklikleri bu sayfa üzerinden takip edebilirsiniz.',
            ),

            const SizedBox(height: 48),
            Center(
              child: Text(
                'Son Güncelleme: Ocak 2026',
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

  Widget _buildSection(bool isDark, {required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
