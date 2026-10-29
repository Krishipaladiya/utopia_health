import 'package:flutter/material.dart';

/// The API sends UTC timestamps without a "Z"; treat them as UTC.
DateTime parseUtc(String s) {
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
  return DateTime.parse(hasZone ? s : '${s}Z').toLocal();
}

String relativeTime(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays}d ago';
  if (d.inDays < 30) return '${d.inDays ~/ 7} wk ago';
  return '${d.inDays ~/ 30} mo ago';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

enum QueueStatus { inConsult, waiting, scheduled, completed, missed }

QueueStatus _statusFrom(String s) => switch (s) {
      'InConsult' => QueueStatus.inConsult,
      'Scheduled' => QueueStatus.scheduled,
      'Completed' => QueueStatus.completed,
      'Missed' => QueueStatus.missed,
      _ => QueueStatus.waiting,
    };

class Patient {
  const Patient({
    required this.dbId,
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.lastVisit,
    required this.complaint,
    this.lastRemedy,
    this.whatsAppConsent = true,
  });

  /// Database id (used by the API).
  final int dbId;

  /// Clinic patient code shown to people, e.g. UH-0001.
  final String id;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final String lastVisit;
  final String complaint;
  final String? lastRemedy;

  /// Patient agreed to get prescriptions and reminders on WhatsApp.
  final bool whatsAppConsent;

  String get genderShort => gender == 'Male' ? 'M' : 'F';

  factory Patient.fromJson(Map<String, dynamic> j) {
    final last = j['lastVisitAt'] as String?;
    return Patient(
      dbId: j['id'] as int,
      id: j['code'] as String,
      name: j['name'] as String,
      age: j['age'] as int,
      gender: j['gender'] as String,
      phone: j['phone'] as String,
      complaint: (j['complaint'] as String?) ?? '',
      lastRemedy: j['lastRemedy'] as String?,
      whatsAppConsent: (j['whatsAppConsent'] as bool?) ?? true,
      lastVisit: last == null ? 'new' : relativeTime(parseUtc(last)),
    );
  }
}

class QueueToken {
  const QueueToken({
    required this.id,
    required this.token,
    required this.patient,
    required this.status,
    required this.waitLabel,
    this.followUp,
    this.miasm,
  });

  /// Database id (used by the API).
  final int id;

  /// Token number shown on screen.
  final int token;
  final Patient patient;
  final QueueStatus status;
  final String waitLabel;
  final int? followUp;
  final String? miasm;

  String get tokenLabel => '#${token.toString().padLeft(2, '0')}';

  factory QueueToken.fromJson(Map<String, dynamic> j) {
    final status = _statusFrom(j['status'] as String);
    final wait = (j['waitMinutes'] as int?) ?? 0;
    return QueueToken(
      id: j['id'] as int,
      token: j['number'] as int,
      patient: Patient.fromJson(j['patient'] as Map<String, dynamic>),
      status: status,
      waitLabel:
          status == QueueStatus.inConsult ? 'In Room Consultation' : '${wait}m wait',
      followUp: j['followUp'] as int?,
      miasm: j['miasm'] as String?,
    );
  }
}

enum RecordKind { prescription, photo }

class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.kind,
    required this.header,
    required this.date,
    required this.title,
    required this.body,
    this.delivery,
  });

  final int id;
  final RecordKind kind;
  final String header;
  final String date;
  final String title;
  final String body;

  /// WhatsApp delivery: Queued, Sent, Delivered, Read, Failed or Skipped.
  final String? delivery;

  factory RecordEntry.fromJson(Map<String, dynamic> j, String clinicName) {
    final when = parseUtc(j['date'] as String);
    if (j['kind'] == 'prescription') {
      final items = (j['items'] as List)
          .map((e) => '${e['name']} (${e['dose']}, ${e['timing']}, ${e['course']})')
          .join(' + ');
      final notes = (j['notes'] as String?) ?? '';
      return RecordEntry(
        id: j['id'] as int,
        kind: RecordKind.prescription,
        header: 'Prescription Record • $clinicName',
        date: shortDate(when),
        title: 'REMEDIES PRESCRIBED',
        body: notes.isEmpty ? items : '$items\n$notes',
        delivery: j['whatsApp'] as String?,
      );
    }
    return RecordEntry(
      id: j['id'] as int,
      kind: RecordKind.photo,
      header: 'Photo Upload • ${relativeTime(when)}',
      date: shortDate(when),
      title: (j['fileName'] as String?) ?? 'Attached report',
      body: 'Uploaded by $clinicName',
    );
  }
}

class Remedy {
  const Remedy({
    required this.name,
    required this.common,
    required this.type,
    this.family,
    this.affinity,
    this.indications,
    this.worse,
    this.better,
    this.potencies = const ['30CH', '200CH', '1M', 'Q'],
    this.favorite = false,
  });

  final String name;
  final String common;
  final String type;
  final String? family;
  final String? affinity;
  final String? indications;
  final String? worse;
  final String? better;
  final List<String> potencies;
  final bool favorite;

  factory Remedy.fromJson(Map<String, dynamic> j) => Remedy(
        name: j['name'] as String,
        common: j['common'] as String,
        type: j['type'] as String,
        family: j['family'] as String?,
        affinity: j['affinity'] as String?,
        indications: j['indications'] as String?,
        worse: j['worse'] as String?,
        better: j['better'] as String?,
        potencies: (j['potencies'] as List).cast<String>(),
      );
}

class LedgerEntry {
  const LedgerEntry({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.note,
    required this.icon,
    this.tag,
  });

  final String title;
  final String subtitle;
  final String? tag;
  final int amount;
  final bool isIncome;
  final String note;
  final IconData icon;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) {
    final income = j['isIncome'] as bool;
    final mode = (j['mode'] as String?) ?? '';
    final icon = !income
        ? Icons.receipt_long_outlined
        : mode == 'Cash'
            ? Icons.currency_rupee_rounded
            : Icons.payments_outlined;
    return LedgerEntry(
      title: j['title'] as String,
      subtitle: j['subtitle'] as String,
      tag: j['tag'] as String?,
      amount: j['amount'] as int,
      isIncome: income,
      note: (j['note'] as String?) ?? '',
      icon: icon,
    );
  }
}

enum NotificationKind { checkIn, payment, appointment, prescription }

NotificationKind _kindFrom(String s) => switch (s) {
      'payment' => NotificationKind.payment,
      'appointment' => NotificationKind.appointment,
      'prescription' => NotificationKind.prescription,
      _ => NotificationKind.checkIn,
    };

class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  final int id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime time;
  bool read;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    // SignalR sends camelCase keys with an upper-case first letter removed;
    // both the REST list and the live event use the same names.
    return AppNotification(
      id: j['id'] as int,
      kind: _kindFrom(j['kind'] as String),
      title: j['title'] as String,
      body: j['body'] as String,
      time: parseUtc(j['createdAt'] as String),
      read: (j['read'] as bool?) ?? false,
    );
  }
}

class FinanceSummary {
  const FinanceSummary({
    required this.net,
    required this.income,
    required this.spend,
    required this.incomeCount,
    this.changePercent,
  });

  final int net;
  final int income;
  final int spend;
  final int incomeCount;
  final double? changePercent;

  static const empty = FinanceSummary(net: 0, income: 0, spend: 0, incomeCount: 0);

  factory FinanceSummary.fromJson(Map<String, dynamic> j) => FinanceSummary(
        net: j['net'] as int,
        income: j['income'] as int,
        spend: j['spend'] as int,
        incomeCount: j['incomeCount'] as int,
        changePercent: (j['changePercent'] as num?)?.toDouble(),
      );
}

enum AppointmentStatus { booked, done, missed, cancelled }

AppointmentStatus _apptStatusFrom(String s) => switch (s) {
      'Done' => AppointmentStatus.done,
      'Missed' => AppointmentStatus.missed,
      'Cancelled' => AppointmentStatus.cancelled,
      _ => AppointmentStatus.booked,
    };

class Appointment {
  const Appointment({
    required this.id,
    required this.start,
    required this.status,
    required this.patient,
  });

  final int id;

  /// Clinic-local date and time (the API sends it without a time zone).
  final DateTime start;
  final AppointmentStatus status;
  final Patient patient;

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as int,
        start: DateTime.parse(j['start'] as String),
        status: _apptStatusFrom(j['status'] as String),
        patient: Patient.fromJson(j['patient'] as Map<String, dynamic>),
      );
}

class SlotInfo {
  const SlotInfo({
    required this.startMin,
    required this.capacity,
    required this.booked,
    required this.available,
  });

  final int startMin;
  final int capacity;
  final int booked;
  final int available;

  factory SlotInfo.fromJson(Map<String, dynamic> j) => SlotInfo(
        startMin: j['startMin'] as int,
        capacity: j['capacity'] as int,
        booked: j['booked'] as int,
        available: j['available'] as int,
      );
}
