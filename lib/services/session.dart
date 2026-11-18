import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who is signed in. One app, different screens and permissions per role:
/// doctor, reception (front desk), clinic (partner clinic / dispensary),
/// lab (laboratory assistant) and patient.
class AppSession extends ChangeNotifier {
  static const _roleKey = 'session_role';
  static const _phoneKey = 'last_phone';

  String role = 'doctor';
  String phone = '';

  /// Front desk / partner clinic / lab user: their own name.
  String memberName = '';

  /// Partner clinic or lab they work for.
  int? facilityId;
  String facilityName = '';
  String facilityKind = '';

  bool get isDoctor => role == 'doctor';
  bool get isReception => role == 'reception';

  /// Doctor or front desk: the clinic screens.
  bool get isClinicTeam => role == 'doctor' || role == 'reception';
  bool get isFacility => role == 'clinic' || role == 'lab';
  bool get isLab => role == 'lab';
  bool get isPatient => role == 'patient';

  String get roleLabel => switch (role) {
        'doctor' => 'Doctor',
        'reception' => 'Front desk',
        'clinic' => 'Partner clinic',
        'lab' => 'Laboratory',
        _ => 'Patient',
      };

  void apply(Map<String, dynamic> data) {
    role = (data['role'] as String?) ?? 'doctor';
    phone = (data['phone'] as String?) ?? phone;
    final member = data['member'] as Map<String, dynamic>?;
    memberName = (member?['name'] as String?) ?? '';
    if (member?['phone'] is String) phone = member!['phone'] as String;
    final facility = data['facility'] as Map<String, dynamic>?;
    facilityId = facility?['id'] as int?;
    facilityName = (facility?['name'] as String?) ?? '';
    facilityKind = (facility?['kind'] as String?) ?? '';
    notifyListeners();
    _save();
  }

  void clear() {
    role = 'doctor';
    memberName = '';
    facilityId = null;
    facilityName = '';
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roleKey, role);
    } catch (_) {}
  }

  /// The number typed last time, so login is one tap next time.
  static Future<String> lastPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> rememberPhone(String digits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_phoneKey, digits);
    } catch (_) {}
  }
}

final session = AppSession();
