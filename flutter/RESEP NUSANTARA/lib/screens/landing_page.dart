import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Set up animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Create a scale animation that starts at 0.8 and ends at 1.0
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start the animation
    _animationController.forward();

    // Set up timer to navigate to onboarding screen after 3 seconds
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/onboarding');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
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
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Area logo dengan animasi
              ScaleTransition(
                scale: _animation,
                child: Image.asset(
                  'assets/images/resep_nusantara_logo.png',
                  fit: BoxFit.contain,
                  height: 300,
                  width: 300,
                ),
              ),

              const SizedBox(height: 136),
            ],
          ),
        ),
      ),
    );
  }
}
