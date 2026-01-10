import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedGender = ''; // 'male' or 'female'

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildGenderButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fixes white area at bottom
      resizeToAvoidBottomInset: true, // Allows the view to scroll when keyboard opens
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/onboarding_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Full Screen Grey/Dark Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.65), // Full screen overlay
            ),
          ),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    
                    // Logo
                    Container(
                      width: 250,
                      height: 180, // Reduced height to move content up
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Image.asset(
                        'assets/headerlogo_beyaz.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 0),
                    
                    // Headlines
                    const Text(
                      'Haberleri Takip\nEtmeye Başla',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32, // Slightly smaller to save space
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16), // Reduced spacing
                    Text(
                      'Kamuoyu Aydınlatma Platformunda yayınlanan haberleri anında yakalayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    
                    const SizedBox(height: 24), // Reduced spacing
                    
                    // Name Field
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ad Soyad',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Gender Selection
                    Row(
                      children: [
                        Expanded(
                          child: _buildGenderButton(
                            label: 'Erkek',
                            isSelected: _selectedGender == 'male',
                            selectedColor: Colors.blue.shade700,
                            onTap: () => setState(() => _selectedGender = 'male'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGenderButton(
                            label: 'Kadın',
                            isSelected: _selectedGender == 'female',
                            selectedColor: Colors.purple.shade600,
                            onTap: () => setState(() => _selectedGender = 'female'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Join Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lütfen adınızı ve soyadınızı girin.')),
                            );
                            return;
                          }
                          if (_selectedGender.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lütfen cinsiyet seçimi yapın.')),
                            );
                            return;
                          }
                          
                          Provider.of<UserService>(context, listen: false)
                              .setProfile(name: name, gender: _selectedGender);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF002B3A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Hemen Katıl',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48), // Padding before footer
                    
                    // Footer Text
                    Text(
                      'Devam ederek Kullanım Koşulları ve Gizlilik Politikası\'nı\nkabul etmiş sayılırsınız.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
