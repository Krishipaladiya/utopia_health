import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/wave_background.dart';
import 'auth/add_phone_screen.dart';
import 'auth/login_screen.dart';
import 'home_shell.dart';

/// Launch screen: the logo grows in, the waves rise, then the app opens
/// on Home (signed in) or Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  late final _logoScale = Tween(begin: 0.72, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Curves.easeOutBack)));
  late final _logoFade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.4, curve: Curves.easeOut));
  late final _waves = CurvedAnimation(parent: _c, curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic));
  late final _tagline = CurvedAnimation(parent: _c, curve: const Interval(0.5, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    // Show the animation for at least 1.9 s while the saved login is checked.
    final results = await Future.wait([
      auth.restore(),
      Future<void>.delayed(const Duration(milliseconds: 1900)),
    ]);
    if (!mounted) return;
    final loggedIn = results.first as bool;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => !loggedIn
            ? const LoginScreen()
            : auth.needsPhone
                ? const AddPhoneScreen()
                : const HomeShell(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(curved), child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waves,
              builder: (context, child) => FractionalTranslation(
                translation: Offset(0, 0.35 * (1 - _waves.value)),
                child: Opacity(opacity: _waves.value, child: child),
              ),
              child: const WaveBackground(),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const Image(image: AssetImage('assets/images/logo_stacked.png'), width: 230),
                  ),
                ),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: _tagline,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(_tagline),
                    child: Column(
                      children: [
                        Text(
                          'Smart care for your clinic',
                          style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 18),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
