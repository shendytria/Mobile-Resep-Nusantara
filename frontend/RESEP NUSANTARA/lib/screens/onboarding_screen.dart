import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _navigationTimer;

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Jika sudah di slide ketiga (index 2), set timer untuk auto navigate
    if (index == 2) {
      _navigationTimer = Timer(const Duration(seconds: 3), () {
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      // Cancel timer jika user swipe balik ke slide sebelumnya
      _navigationTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: const [
                OnboardingPage(
                  imagePath: 'assets/images/resep_nusantara_logo.png',
                  title: 'Temukan ribuan resep autentik nusantara',
                ),
                OnboardingPage(
                  imagePath: 'assets/images/resep_nusantara_logo.png',
                  title: 'Lestarikan cita rasa warisan nenek moyang',
                ),
                OnboardingPage(
                  imagePath: 'assets/images/resep_nusantara_logo.png',
                  title: 'Mulai perjalanan kuliner Anda hari ini!',
                ),
              ],
            ),
          ),
          // Indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? const Color(0xFF0D5C46)
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Tampilkan pesan loading di slide ketiga
                if (_currentIndex == 2)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D5C46)),
                        strokeWidth: 2,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Menuju halaman masuk...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF0D5C46),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String imagePath;
  final String title;

  const OnboardingPage({
    super.key,
    required this.imagePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Image.asset(imagePath, height: 300, width: 300, fit: BoxFit.contain),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D5C46),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}