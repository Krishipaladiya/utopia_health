import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/public/checkin_page.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const UtopiaHealthApp());
}

/// Clinic code when the web portal was opened from a check-in QR.
final String? _checkInCode = RegExp(r'checkin/([A-Za-z0-9]{4,12})').firstMatch(Uri.base.toString())?.group(1)?.toUpperCase();

class UtopiaHealthApp extends StatelessWidget {
  const UtopiaHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Utopia Health',
      debugShowCheckedModeBanner: false,
      navigatorKey: auth.navigatorKey,
      theme: AppTheme.light(),
      // Web portal: a clinic's QR opens .../portal/#/checkin/CODE.
      home: _checkInCode == null ? const SplashScreen() : CheckInPage(code: _checkInCode!),
    );
  }
}
