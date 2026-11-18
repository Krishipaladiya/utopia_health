import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/appointments_store.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../data/network_stores.dart';
import '../data/reminders.dart';
import '../models/network.dart';
import '../screens/auth/login_screen.dart';
import 'api_client.dart';
import 'app_navigator.dart';
import 'push_service.dart';
import 'realtime_service.dart';
import 'session.dart';

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

  String? _proof;

  /// Login for every role. Returns the accounts to choose from when the number
  /// has more than one clinic account; otherwise signs in and returns null.
  Future<List<LoginChoice>?> login(String phone, String code) async {
    final data = await api.post('/api/auth/login', {'phone': phone, 'code': code}) as Map<String, dynamic>;
    await AppSession.rememberPhone(phone);
    if (data['choose'] is List) {
      _proof = data['proof'] as String;
      return (data['choose'] as List).map((e) => LoginChoice.fromJson(e as Map<String, dynamic>)).toList();
    }
    await _finish(data);
    return null;
  }

  // ---- login without SMS --------------------------------------------------

  Map<String, dynamic>? _methods;

  /// Which logins work right now: {sms, email, google, apple}. SMS is off until a provider is connected.
  Future<Map<String, dynamic>> methods() async {
    if (_methods != null) return _methods!;
    try {
      _methods = await api.get('/api/auth/methods') as Map<String, dynamic>;
    } on ApiException {
      return {'sms': false, 'email': true, 'google': true, 'apple': true};
    }
    return _methods!;
  }

  String? _emailProof;

  /// Email-code login. Returns accounts to choose from, or null when signed in.
  Future<List<LoginChoice>?> loginEmail(String email, String code) async {
    final data = await api.post('/api/auth/email/login', {'email': email, 'code': code}) as Map<String, dynamic>;
    if (data['choose'] is List) {
      _emailProof = data['proof'] as String;
      return (data['choose'] as List).map((e) => LoginChoice.fromJson(e as Map<String, dynamic>)).toList();
    }
    await _finish(data);
    return null;
  }

  Future<void> selectEmail(LoginChoice choice) async {
    final data = await api.post('/api/auth/email/select', {
      'proof': _emailProof,
      'role': choice.role,
      'id': choice.id,
      'phone': choice.phone,
    }) as Map<String, dynamic>;
    await _finish(data);
  }

  /// Doctor sign-up with an email code. Returns true when the mobile number is still needed.
  Future<bool> signupEmail(String email, String code, String name) async {
    final data = await api.post('/api/auth/email/signup', {'email': email, 'code': code, 'name': name}) as Map<String, dynamic>;
    await _finish(data);
    return data['needsPhone'] == true;
  }

  /// Patient login with the code (or link) the clinic sent on WhatsApp.
  Future<void> loginWithLink(String code) async {
    final data = await api.post('/api/auth/link/login', {'code': code}) as Map<String, dynamic>;
    await _finish(data);
  }

  // ---- PIN for quick login on this phone ------------------------------------

  static const _deviceKey = 'device_id';
  static const _pinsKey = 'saved_pins';

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  Future<List<SavedPin>> savedPins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pinsKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => SavedPin.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePins(List<SavedPin> pins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinsKey, jsonEncode(pins.map((p) => p.toJson()).toList()));
  }

  /// Sets (or changes) the PIN for the account signed in now.
  Future<void> setPin(String pin) async {
    final data = await api.post('/api/auth/pin', {'deviceId': await _deviceId(), 'pin': pin}) as Map<String, dynamic>;
    final saved = SavedPin(pinId: data['pinId'] as int, name: data['name'] as String, role: data['role'] as String);
    final pins = (await savedPins()).where((p) => p.pinId != saved.pinId).toList()..insert(0, saved);
    await _savePins(pins);
  }

  /// True when the account signed in now has no PIN on this phone yet.
  Future<bool> shouldOfferPin() async {
    final pins = await savedPins();
    final name = session.isPatient ? 'Patient ${session.phone}' : (session.isClinicTeam && session.isDoctor ? doctorProfile.name : session.memberName);
    return !pins.any((p) => p.role == session.role && p.name == name);
  }

  Future<void> pinLogin(SavedPin saved, String pin) async {
    try {
      final data = await api.post('/api/auth/pin/login', {
        'deviceId': await _deviceId(),
        'pinId': saved.pinId,
        'pin': pin,
      }) as Map<String, dynamic>;
      await _finish(data);
    } on ApiException catch (e) {
      if (e.code == 'pin_not_set' || e.code == 'not_registered') await forgetPin(saved);
      rethrow;
    }
  }

  Future<void> forgetPin(SavedPin saved) async {
    try {
      await api.delete('/api/auth/pin/${saved.pinId}?deviceId=${await _deviceId()}');
    } on ApiException {
      // removed here anyway
    }
    await _savePins((await savedPins()).where((p) => p.pinId != saved.pinId).toList());
  }

  /// After the chooser.
  Future<void> select(LoginChoice choice) async {
    final data = await api.post('/api/auth/select', {
      'proof': _proof,
      'role': choice.role,
      'id': choice.id,
    }) as Map<String, dynamic>;
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

  /// Google / Apple sign-in. The first time, the server creates the account.
  /// Returns true when the doctor still has to add a mobile number.
  Future<bool> socialLogin(String provider, String idToken, {String? name}) async {
    final data = await api.post(
      '/api/auth/social',
      {'provider': provider, 'idToken': idToken, 'name': name},
    ) as Map<String, dynamic>;
    await _finish({...data, 'role': 'doctor'});
    return data['needsPhone'] == true;
  }

  /// Adds the mobile number (checked with the SMS code) and the clinic name.
  Future<void> addPhone(String phone, String code, {String? clinicName}) async {
    final data = await api.post(
      '/api/doctor/phone',
      {'phone': phone, 'code': code, 'clinicName': clinicName},
    ) as Map<String, dynamic>;
    doctorProfile.applyJson(data);
  }

  /// Signed in but no mobile number yet (first Google / Apple sign-in).
  bool get needsPhone => api.hasSession && session.isDoctor && doctorProfile.phone.isEmpty;

  Future<void> _finish(Map<String, dynamic> data) async {
    await api.saveSession(data['token'] as String);
    session.apply(data);
    if (data['doctor'] is Map) doctorProfile.applyJson(data['doctor'] as Map<String, dynamic>);
  }

  /// At app start: is there a saved login that the server still accepts?
  Future<bool> restore() async {
    await api.loadSession();
    api.onUnauthorized = _kickToLogin;
    if (!api.hasSession) return false;
    try {
      final data = await api.get('/api/session') as Map<String, dynamic>;
      session.apply(data);
      if (data['doctor'] is Map) doctorProfile.applyJson(data['doctor'] as Map<String, dynamic>);
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
    if (session.isPatient) {
      await medicineReminders.loadSetting();
      await Future.wait([patientStore.loadAll(), RealtimeService.instance.start()]);
      await PushService.instance.start();
      return;
    }
    if (session.isFacility) {
      await Future.wait([facilityStore.loadAll(), RealtimeService.instance.start()]);
      await PushService.instance.start();
      return;
    }
    await Future.wait([
      clinic.loadAll(),
      appointments.refresh(),
      slotConfig.load().catchError((_) {}),
      RealtimeService.instance.start(),
    ]);
    // Alerts while the app is closed (needs the Firebase config files).
    await PushService.instance.start();
  }

  /// Deletes the signed-in account on the server, forgets its PINs here, signs out.
  Future<void> deleteAccount() async {
    await api.post('/api/account/delete', {'confirm': 'DELETE'});
    final pins = await savedPins();
    await _savePins(pins.where((p) => p.role != session.role).toList());
    await logout();
  }

  Future<void> logout() async {
    await PushService.instance.stop();
    await RealtimeService.instance.stop();
    await api.clearSession();
    clinic.reset();
    appointments.reset();
    patientStore.reset();
    facilityStore.reset();
    await medicineReminders.clear();
    session.clear();
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
