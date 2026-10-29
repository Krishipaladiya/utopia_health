import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const UtopiaHealthApp());
}

class UtopiaHealthApp extends StatelessWidget {
  const UtopiaHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Utopia Health',
      debugShowCheckedModeBanner: false,
      navigatorKey: auth.navigatorKey,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
