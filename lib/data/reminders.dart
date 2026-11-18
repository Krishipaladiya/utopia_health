import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/network.dart';
import '../services/notification_service.dart';

/// One time of day with the medicines to take then.
class DoseTime {
  const DoseTime({required this.label, required this.hour, required this.minute, required this.lines});

  final String label;
  final int hour;
  final int minute;

  /// "Rajesh: Nux Vomica 30CH • ½ Pill (Before food)"
  final List<String> lines;

  String get timeText {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Medicine reminders built from the patient's prescriptions: each timing
/// (Dawn, Noon, Dusk, Moon) becomes a daily alert while the course lasts.
class MedicineReminders extends ChangeNotifier {
  static const _enabledKey = 'medicine_reminders_on';
  static const _baseId = 500000;

  /// Default clock time for each prescription timing.
  static const times = {
    'Dawn': (7, 0),
    'Morning': (8, 0),
    'Noon': (13, 0),
    'Afternoon': (14, 0),
    'Dusk': (19, 0),
    'Evening': (18, 0),
    'Moon': (21, 30),
    'Night': (21, 30),
  };

  bool enabled = true;
  List<DoseTime> today = [];
  int _scheduled = 0;

  Future<void> loadSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {}
  }

  Future<void> setEnabled(bool on, List<MyPrescription> prescriptions) async {
    enabled = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, on);
    } catch (_) {}
    if (on) await NotificationService.instance.requestPermission();
    await sync(prescriptions);
  }

  /// Rebuilds today's list and the daily alerts from the active courses.
  Future<void> sync(List<MyPrescription> prescriptions) async {
    final now = DateTime.now();
    final byTime = <String, List<String>>{};
    for (final rx in prescriptions) {
      for (final item in rx.items) {
        final days = int.tryParse(RegExp(r'(\d+)\s*Day').firstMatch(item.course)?.group(1) ?? '') ?? 7;
        if (now.isAfter(rx.date.add(Duration(days: days)))) continue;
        final food = RegExp(r'\((Before|After)\)').firstMatch(item.timing)?.group(1);
        for (final key in times.keys) {
          if (!item.timing.contains(key)) continue;
          final line = '${rx.memberName}: ${item.name} • ${item.dose}${food == null ? '' : ' ($food food)'}';
          byTime.putIfAbsent(key, () => []).add(line);
        }
      }
    }

    today = [
      for (final e in byTime.entries)
        DoseTime(label: e.key, hour: times[e.key]!.$1, minute: times[e.key]!.$2, lines: e.value),
    ]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    notifyListeners();

    for (var i = 0; i < _scheduled; i++) {
      await NotificationService.instance.cancel(_baseId + i);
    }
    _scheduled = 0;
    if (!enabled) return;
    for (final d in today) {
      await NotificationService.instance.scheduleDaily(
        id: _baseId + _scheduled,
        title: 'Medicine time (${d.label})',
        body: d.lines.join('\n'),
        hour: d.hour,
        minute: d.minute,
      );
      _scheduled++;
    }
  }

  Future<void> clear() async {
    for (var i = 0; i < 10; i++) {
      await NotificationService.instance.cancel(_baseId + i);
    }
    today = [];
    _scheduled = 0;
  }
}

final medicineReminders = MedicineReminders();
