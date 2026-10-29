import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import 'clinic_store.dart';

String apiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Clinic-local date and time without a zone, as the API expects.
String apiDateTime(DateTime d) =>
    '${apiDate(d)}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

/// Appointments for one chosen day plus today's list (for the Home card).
/// Refreshed live when the server sends "appointments.changed".
class AppointmentsStore extends ChangeNotifier {
  DateTime selectedDate = _dateOnly(DateTime.now());
  List<Appointment> selected = [];
  List<Appointment> today = [];
  bool loading = false;
  String? error;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get selectedIsToday => selectedDate == _dateOnly(DateTime.now());

  int countToday(AppointmentStatus s) => today.where((a) => a.status == s).length;

  /// Next booked appointment today that has not passed (or the first booked one).
  Appointment? get nextToday {
    final booked = today.where((a) => a.status == AppointmentStatus.booked).toList();
    if (booked.isEmpty) return null;
    final now = DateTime.now();
    return booked.firstWhere((a) => !a.start.isBefore(now), orElse: () => booked.first);
  }

  Future<List<Appointment>> _fetch(DateTime day) async {
    final data = await api.get('/api/appointments', query: {'date': apiDate(day)}) as List;
    return data.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final now = _dateOnly(DateTime.now());
      today = await _fetch(now);
      selected = selectedDate == now ? today : await _fetch(selectedDate);
      error = null;
    } on ApiException catch (e) {
      error = e.friendly;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> selectDate(DateTime day) async {
    selectedDate = _dateOnly(day);
    await refresh();
  }

  void reset() {
    selectedDate = _dateOnly(DateTime.now());
    selected = [];
    today = [];
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<List<SlotInfo>> availableSlots(DateTime day) async {
    final data = await api.get('/api/appointments/available', query: {'date': apiDate(day)}) as List;
    return data.map((e) => SlotInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Throws [ApiException] (slot_full, slot_in_past, not_a_slot).
  Future<void> book(Patient patient, DateTime start) async {
    await api.post('/api/appointments', {
      'patientId': patient.dbId,
      'start': apiDateTime(start),
    });
    await refresh();
  }

  Future<void> markMissed(Appointment a) async {
    await api.post('/api/appointments/${a.id}/missed');
    await refresh();
  }

  Future<void> cancel(Appointment a) async {
    await api.post('/api/appointments/${a.id}/cancel');
    await refresh();
  }

  /// Patient arrived: they join today's queue and the appointment is closed.
  Future<void> checkIn(Appointment a) async {
    await api.post('/api/appointments/${a.id}/check-in');
    await Future.wait([refresh(), clinic.refreshQueue()]);
  }
}

final appointments = AppointmentsStore();
