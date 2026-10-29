import 'package:flutter/material.dart';

import '../services/api_client.dart';

// In-memory demo state for the doctor's profile and slot setup.
// Replace with real storage / API later.

class DoctorProfile extends ChangeNotifier {
  String name = 'Dr. Arvind Patel';
  String qualification = 'BHMS';
  String speciality = 'Homeopathy';
  String clinic = 'Shri Hari Clinic';
  String regNo = 'G-12345';
  String phone = '+91 98250 14820';
  String email = '';
  int fee = 300;
  int experienceYears = 12;
  String languages = 'Gujarati, Hindi, English';
  String bio =
      'Classical homeopath focused on chronic and recurring complaints. '
      'Detailed case taking with follow-up care for the whole family.';

  String get initials {
    final words = name
        .replaceAll('Dr.', '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return 'DR';
    return words.map((w) => w[0].toUpperCase()).join();
  }

  /// Short line used under the clinic name in headers.
  String get headerLine => qualification.isEmpty ? name : '$name, $qualification';

  void applyJson(Map<String, dynamic> j) {
    name = j['name'] as String;
    phone = j['phone'] as String;
    email = (j['email'] as String?) ?? '';
    qualification = j['qualification'] as String;
    speciality = (j['speciality'] as String?) ?? '';
    clinic = (j['clinicName'] as String?) ?? clinic;
    regNo = (j['regNo'] as String?) ?? '';
    fee = (j['fee'] as int?) ?? fee;
    experienceYears = (j['experienceYears'] as int?) ?? 0;
    languages = (j['languages'] as String?) ?? '';
    bio = (j['bio'] as String?) ?? '';
    notifyListeners();
  }

  Future<void> load() async {
    applyJson(await api.get('/api/doctor/profile') as Map<String, dynamic>);
  }

  /// Sends the current values to the server.
  Future<void> save() async {
    final j = await api.put('/api/doctor/profile', {
      'name': name,
      'qualification': qualification,
      'speciality': speciality,
      'clinicName': clinic,
      'regNo': regNo,
      'fee': fee,
      'experienceYears': experienceYears,
      'languages': languages,
      'bio': bio,
    });
    applyJson(j as Map<String, dynamic>);
  }

  void update({
    String? name,
    String? qualification,
    String? speciality,
    String? clinic,
    String? regNo,
    String? phone,
    int? fee,
    int? experienceYears,
    String? languages,
    String? bio,
  }) {
    this.name = name ?? this.name;
    this.qualification = qualification ?? this.qualification;
    this.speciality = speciality ?? this.speciality;
    this.clinic = clinic ?? this.clinic;
    this.regNo = regNo ?? this.regNo;
    this.phone = phone ?? this.phone;
    this.fee = fee ?? this.fee;
    this.experienceYears = experienceYears ?? this.experienceYears;
    this.languages = languages ?? this.languages;
    this.bio = bio ?? this.bio;
    notifyListeners();
  }
}

class TimeRange {
  const TimeRange(this.start, this.end);

  final TimeOfDay start;
  final TimeOfDay end;

  int get startMin => start.hour * 60 + start.minute;
  int get endMin => end.hour * 60 + end.minute;

  bool overlaps(TimeRange other) =>
      startMin < other.endMin && other.startMin < endMin;
}

class DaySchedule {
  DaySchedule({required this.enabled, required this.sessions});

  bool enabled;
  List<TimeRange> sessions;

  DaySchedule copy() =>
      DaySchedule(enabled: enabled, sessions: List.of(sessions));
}

String formatTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

String formatMinutes(int minutes) {
  return formatTime(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
}

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class SlotConfig extends ChangeNotifier {
  SlotConfig() {
    for (var d = 1; d <= 7; d++) {
      days[d] = DaySchedule(
        enabled: d != 7,
        sessions: const [
          TimeRange(
            TimeOfDay(hour: 10, minute: 0),
            TimeOfDay(hour: 13, minute: 0),
          ),
          TimeRange(
            TimeOfDay(hour: 17, minute: 0),
            TimeOfDay(hour: 20, minute: 0),
          ),
        ],
      );
    }
  }

  /// Keys 1..7 = Monday..Sunday.
  final Map<int, DaySchedule> days = {};

  int slotMinutes = 15;
  int capacity = 1;
  bool remindOnDay = true;
  bool notifyDoctor = true;
  bool allowMissed = true;

  /// Appointments the doctor can take in one hour.
  int get perHour => (60 / slotMinutes * capacity).floor();

  List<int> slotStartsFor(DaySchedule day) {
    final starts = <int>[];
    for (final s in day.sessions) {
      for (var t = s.startMin; t + slotMinutes <= s.endMin; t += slotMinutes) {
        starts.add(t);
      }
    }
    starts.sort();
    return starts;
  }

  int appointmentsFor(DaySchedule day) =>
      slotStartsFor(day).length * capacity;

  int? get firstEnabledDay {
    for (var d = 1; d <= 7; d++) {
      if (days[d]!.enabled) return d;
    }
    return null;
  }

  /// e.g. "Mon–Sat" or "Mon, Wed, Fri".
  String get daysSummary {
    final on = [for (var d = 1; d <= 7; d++) if (days[d]!.enabled) d];
    if (on.isEmpty) return 'No days set';
    final abbr = [for (final d in on) weekdayNames[d - 1].substring(0, 3)];
    final contiguous = on.length > 2 && on.last - on.first == on.length - 1;
    if (contiguous) return '${abbr.first}–${abbr.last}';
    return abbr.join(', ');
  }

  String get summary =>
      '$daysSummary • $slotMinutes min • $perHour/hr';

  void setSlotMinutes(int v) {
    slotMinutes = v;
    notifyListeners();
  }

  void setCapacity(int v) {
    capacity = v.clamp(1, 10);
    notifyListeners();
  }

  void applyPreset(int minutes, int cap) {
    slotMinutes = minutes;
    capacity = cap;
    notifyListeners();
  }

  void setEnabled(int day, bool value) {
    days[day]!.enabled = value;
    notifyListeners();
  }

  /// Returns false if the new range overlaps another session that day.
  bool addSession(int day, TimeRange range) {
    final d = days[day]!;
    if (d.sessions.any(range.overlaps)) return false;
    d.sessions = [...d.sessions, range]
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    notifyListeners();
    return true;
  }

  bool replaceSession(int day, int index, TimeRange range) {
    final d = days[day]!;
    final others = [
      for (var i = 0; i < d.sessions.length; i++)
        if (i != index) d.sessions[i],
    ];
    if (others.any(range.overlaps)) return false;
    d.sessions = [...others, range]
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    notifyListeners();
    return true;
  }

  void removeSession(int day, int index) {
    final d = days[day]!;
    if (d.sessions.length <= 1) return;
    d.sessions = [
      for (var i = 0; i < d.sessions.length; i++)
        if (i != index) d.sessions[i],
    ];
    notifyListeners();
  }

  void copyDayToAll(int from) {
    final src = days[from]!;
    for (var d = 1; d <= 7; d++) {
      if (d == from) continue;
      days[d] = DaySchedule(enabled: src.enabled, sessions: List.of(src.sessions));
    }
    notifyListeners();
  }

  Future<void> load() async {
    final j = await api.get('/api/doctor/slots') as Map<String, dynamic>;
    _apply(j);
  }

  /// Sends the current setup to the server (it validates overlaps etc.).
  Future<void> save() async {
    final j = await api.put('/api/doctor/slots', {
      'slotMinutes': slotMinutes,
      'capacity': capacity,
      'remindOnDay': remindOnDay,
      'notifyDoctor': notifyDoctor,
      'allowMissed': allowMissed,
      'days': [
        for (var d = 1; d <= 7; d++)
          {
            'weekday': d,
            'enabled': days[d]!.enabled,
            'sessions': [
              for (final s in days[d]!.sessions)
                {'startMin': s.startMin, 'endMin': s.endMin},
            ],
          },
      ],
    });
    _apply(j as Map<String, dynamic>);
  }

  void _apply(Map<String, dynamic> j) {
    slotMinutes = j['slotMinutes'] as int;
    capacity = j['capacity'] as int;
    remindOnDay = j['remindOnDay'] as bool;
    notifyDoctor = j['notifyDoctor'] as bool;
    allowMissed = j['allowMissed'] as bool;
    for (final raw in j['days'] as List) {
      final m = raw as Map<String, dynamic>;
      days[m['weekday'] as int] = DaySchedule(
        enabled: m['enabled'] as bool,
        sessions: [
          for (final x in m['sessions'] as List)
            TimeRange(
              TimeOfDay(hour: (x['startMin'] as int) ~/ 60, minute: (x['startMin'] as int) % 60),
              TimeOfDay(hour: (x['endMin'] as int) ~/ 60, minute: (x['endMin'] as int) % 60),
            ),
        ],
      );
    }
    notifyListeners();
  }

  void setRule({bool? remind, bool? notify, bool? missed}) {
    remindOnDay = remind ?? remindOnDay;
    notifyDoctor = notify ?? notifyDoctor;
    allowMissed = missed ?? allowMissed;
    notifyListeners();
  }
}

final doctorProfile = DoctorProfile();
final slotConfig = SlotConfig();
