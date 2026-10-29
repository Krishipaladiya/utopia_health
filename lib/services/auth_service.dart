import 'package:flutter/material.dart';

import '../data/appointments_store.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../screens/auth/login_screen.dart';
import 'api_client.dart';
import 'app_navigator.dart';
import 'push_service.dart';
import 'realtime_service.dart';

/// Login, registration and the signed-in session.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Lets the API client send the user back to login from anywhere.
  final navigatorKey = appNavigatorKey;

  /// Sends an OTP by SMS. Returns the code only when the server is in
  /// development mode.
  Future<String?> sendOtp(String phone) async {
    final data = await api.post('/api/auth/send-otp', {'phone': phone}) as Map<String, dynamic>;
    return data['devCode'] as String?;
  }

  /// Existing doctor. Throws [ApiException] (invalid_otp, not_registered).
  Future<void> login(String phone, String code) async {
    final data =
        await api.post('/api/auth/verify-otp', {'phone': phone, 'code': code}) as Map<String, dynamic>;
    await _finish(data);
  }

  /// Sends a code to an email address. Returns it only on a development server.
  Future<String?> sendEmailOtp(String email) async {
    final data =
        await api.post('/api/auth/send-email-otp', {'email': email}) as Map<String, dynamic>;
    return data['devCode'] as String?;
  }

  /// Checks a phone or email code. Returns a short-lived proof for [requestRegistration].
  Future<String> verifyContact(String kind, String value, String code) async {
    final data = await api.post(
      '/api/auth/verify-contact',
      {'kind': kind, 'value': value, 'code': code},
    ) as Map<String, dynamic>;
    return data['proof'] as String;
  }

  /// A doctor's registration: only the verified mobile number and email.
  /// Our team contacts them and completes the profile.
  Future<void> requestRegistration({required String phoneProof, required String emailProof}) async {
    await api.post('/api/register/request', {'phoneProof': phoneProof, 'emailProof': emailProof});
  }

  /// Google / Apple sign-in for a doctor our team already onboarded.
  Future<void> socialLogin(String provider, String idToken) async {
    final data = await api.post(
      '/api/auth/social',
      {'provider': provider, 'idToken': idToken},
    ) as Map<String, dynamic>;
    await _finish(data);
  }

  Future<void> _finish(Map<String, dynamic> data) async {
    await api.saveSession(data['token'] as String);
    doctorProfile.applyJson(data['doctor'] as Map<String, dynamic>);
  }

  /// At app start: is there a saved login that the server still accepts?
  Future<bool> restore() async {
    await api.loadSession();
    api.onUnauthorized = _kickToLogin;
    if (!api.hasSession) return false;
    try {
      await doctorProfile.load();
      return true;
    } on ApiException catch (e) {
      // Offline: keep the session so the app opens; real errors drop it.
      if (e.code == 'network') return true;
      await api.clearSession();
      return false;
    }
  }

  /// Loads everything and opens the live connection. Call once Home is shown.
  Future<void> startSession() async {
    await Future.wait([
      clinic.loadAll(),
      appointments.refresh(),
      slotConfig.load().catchError((_) {}),
      RealtimeService.instance.start(),
    ]);
    // Alerts while the app is closed (needs the Firebase config files).
    await PushService.instance.start();
  }

  Future<void> logout() async {
    await PushService.instance.stop();
    await RealtimeService.instance.stop();
    await api.clearSession();
    clinic.reset();
    appointments.reset();
  }

  bool _leaving = false;

  void _kickToLogin() {
    if (_leaving) return;
    _leaving = true;
    logout().whenComplete(() {
      _leaving = false;
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }
}

final auth = AuthService.instance;
