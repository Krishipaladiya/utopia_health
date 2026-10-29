import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/wave_background.dart';
import 'auth/add_phone_screen.dart';
import 'auth/login_screen.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Show the splash for at least 1.8 s while the saved login is checked.
    final results = await Future.wait([
      auth.restore(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;
    final loggedIn = results.first as bool;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => !loggedIn
            ? const LoginScreen()
            : auth.needsPhone
                ? const AddPhoneScreen()
                : const HomeShell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(child: WaveBackground()),
          Center(
            child: Image(
              image: AssetImage('assets/images/logo_stacked.png'),
              width: 240,
            ),
          ),
        ],
      ),
    );
  }
}
