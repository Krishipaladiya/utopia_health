import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

/// Live clinic data (queue, patients, ledger) loaded from the .NET API.
/// Screens listen to this. The realtime connection calls the refresh methods
/// whenever the server says something changed.
class ClinicStore extends ChangeNotifier {
  List<Patient> patients = [];
  int patientTotal = 0;
  QueueToken? current;
  List<QueueToken> upcoming = [];
  int completedToday = 0;
  List<LedgerEntry> ledger = [];
  FinanceSummary summary = FinanceSummary.empty;
  FinanceSummary todaySummary = FinanceSummary.empty;
  String period = 'month';

  bool loaded = false;
  String? error;

  int get registeredCount => patientTotal;
  int get monthIncome => summary.income;
  int get monthSpend => summary.spend;
  int get netBalance => summary.net;
  int get todayIncome => todaySummary.income;

  // ---- loading -----------------------------------------------------------

  Future<void> loadAll() async {
    await Future.wait([
      refreshQueue(),
      refreshPatients(),
      refreshFinance(),
      notifications.load(),
    ]);
    loaded = true;
    notifyListeners();
  }

  Future<void> refreshQueue() async {
    try {
      final data = await api.get('/api/queue') as Map<String, dynamic>;
      final cur = data['current'];
      current = cur == null ? null : QueueToken.fromJson(cur as Map<String, dynamic>);
      upcoming = (data['waiting'] as List)
          .map((e) => QueueToken.fromJson(e as Map<String, dynamic>))
          .toList();
      completedToday = data['completedToday'] as int;
      error = null;
    } on ApiException catch (e) {
      error = e.friendly;
    }
    notifyListeners();
  }

  Future<void> refreshPatients() async {
    try {
      final data = await api.get('/api/patients', query: {'take': '200'}) as Map<String, dynamic>;
      patients = (data['items'] as List)
          .map((e) => Patient.fromJson(e as Map<String, dynamic>))
          .toList();
      patientTotal = data['total'] as int;
      error = null;
    } on ApiException catch (e) {
      error = e.friendly;
    }
    notifyListeners();
  }

  Future<void> refreshFinance() async {
    try {
      final results = await Future.wait([
        api.get('/api/finance/ledger', query: {'take': '50'}),
        api.get('/api/finance/summary', query: {'period': period}),
        api.get('/api/finance/summary', query: {'period': 'today'}),
      ]);
      ledger = (results[0] as List)
          .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      summary = FinanceSummary.fromJson(results[1] as Map<String, dynamic>);
      todaySummary = FinanceSummary.fromJson(results[2] as Map<String, dynamic>);
      error = null;
    } on ApiException catch (e) {
      error = e.friendly;
    }
    notifyListeners();
  }

  Future<void> setPeriod(String value) async {
    period = value;
    notifyListeners();
    await refreshFinance();
  }

  void reset() {
    patients = [];
    patientTotal = 0;
    current = null;
    upcoming = [];
    completedToday = 0;
    ledger = [];
    summary = FinanceSummary.empty;
    todaySummary = FinanceSummary.empty;
    loaded = false;
    error = null;
    notifications.reset();
    notifyListeners();
  }

  // ---- queue actions (throw ApiException on failure) ----------------------

  Future<void> callNext(QueueToken token) async {
    await api.post('/api/queue/${token.id}/call');
    await refreshQueue();
  }

  Future<void> completeCurrent() async {
    final c = current;
    if (c == null) return;
    await api.post('/api/queue/${c.id}/complete');
    await refreshQueue();
  }

  // ---- patients ----------------------------------------------------------

  /// Returns the name of someone already using this mobile number, if any.
  Future<String?> addPatient({
    required String name,
    required String phone,
    required int age,
    required String gender,
    String? complaint,
    required bool addToQueue,
    bool whatsAppConsent = true,
    Map<String, String> details = const {},
  }) async {
    final data = await api.post('/api/patients', {
      ...details,
      'name': name,
      'phone': phone,
      'age': age,
      'gender': gender,
      'complaint': complaint,
      'addToQueue': addToQueue,
      'whatsAppConsent': whatsAppConsent,
    }) as Map<String, dynamic>;
    await Future.wait([refreshPatients(), if (addToQueue) refreshQueue()]);
    return data['familyWith'] as String?;
  }

  /// Another patient already using this mobile number (family folder).
  Patient? patientWithPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return null;
    final last10 = digits.substring(digits.length - 10);
    for (final p in patients) {
      if (p.phone.replaceAll(RegExp(r'\D'), '').endsWith(last10)) return p;
    }
    return null;
  }

  /// Finds a mobile number in this clinic and at other doctors' clinics.
  Future<PatientLookup> lookup(String phone) async {
    final data = await api.get('/api/patients/lookup', query: {'phone': phone}) as Map<String, dynamic>;
    return PatientLookup.fromJson(data);
  }

  Future<PatientProfile> profile(Patient patient) async {
    final data = await api.get('/api/patients/${patient.dbId}/profile') as Map<String, dynamic>;
    return PatientProfile.fromJson(data);
  }

  Future<Patient> saveDetails(Patient patient, Map<String, String> details) async {
    final data = await api.put('/api/patients/${patient.dbId}/details', details) as Map<String, dynamic>;
    await refreshPatients();
    return Patient.fromJson(data);
  }

  /// Drop message: every doctor who treats this patient can read it.
  Future<void> addNote(Patient patient, String text) async {
    await api.post('/api/patients/${patient.dbId}/notes', {'text': text});
  }

  Future<void> addVoiceNote(Patient patient, String path, int seconds) async {
    await api.upload('/api/patients/${patient.dbId}/voice', path, fields: {'seconds': '$seconds'});
  }

  Future<void> deleteNote(int id) async {
    await api.delete('/api/notes/$id');
  }

  Future<void> uploadFile(Patient patient, String path, {String? fileName}) async {
    await api.upload('/api/patients/${patient.dbId}/files', path, fileName: fileName);
  }

  Future<List<RecordEntry>> records(Patient patient, String clinicName) async {
    final data = await api.get('/api/patients/${patient.dbId}/records') as List;
    return data
        .map((e) => RecordEntry.fromJson(e as Map<String, dynamic>, clinicName))
        .toList();
  }

  // ---- prescriptions -----------------------------------------------------

  /// Returns the WhatsApp status: Queued, or Skipped if the patient has not agreed.
  Future<String?> prescribe(
    Patient patient,
    List<Map<String, String>> items, {
    bool sendWhatsApp = true,
    String notes = '',
  }) async {
    final data = await api.post('/api/patients/${patient.dbId}/prescriptions', {
      'items': items,
      'notes': notes,
      'sendWhatsApp': sendWhatsApp,
    }) as Map<String, dynamic>;
    await refreshPatients();
    return data['whatsApp'] as String?;
  }

  Future<String?> resendPrescription(int prescriptionId) async {
    final data = await api.post('/api/prescriptions/$prescriptionId/send') as Map<String, dynamic>;
    return data['whatsApp'] as String?;
  }

  /// Record that the patient agreed (or stopped agreeing) to WhatsApp messages.
  Future<void> setWhatsAppConsent(Patient patient, bool consent) async {
    await api.put('/api/patients/${patient.dbId}/whatsapp-consent', {'consent': consent});
    await refreshPatients();
  }

  // ---- finance -----------------------------------------------------------

  Future<void> addFee({
    required String patientName,
    required int amount,
    required String mode,
  }) async {
    await api.post('/api/finance/fees', {
      'patientName': patientName,
      'amount': amount,
      'mode': mode,
    });
    await refreshFinance();
  }

  Future<void> addSpend({
    required String title,
    required int amount,
    required String mode,
  }) async {
    await api.post('/api/finance/spends', {
      'title': title,
      'amount': amount,
      'mode': mode,
    });
    await refreshFinance();
  }
}

/// In-app notification feed backed by the server. New items arrive live over
/// SignalR; each one is also shown as a system notification when allowed.
class NotificationCenter extends ChangeNotifier {
  final List<AppNotification> items = [];

  /// Called with each live item so the UI can show an in-app banner.
  void Function(AppNotification)? onNew;

  int get unread => items.where((n) => !n.read).length;

  Future<void> load() async {
    try {
      final data = await api.get('/api/notifications') as Map<String, dynamic>;
      items
        ..clear()
        ..addAll(
          (data['items'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)),
        );
      notifyListeners();
    } on ApiException {
      // keep what we have
    }
  }

  /// A live "notification.created" event from the server.
  void addFromServer(Map<String, dynamic> json) {
    final n = AppNotification.fromJson(json);
    if (items.any((x) => x.id == n.id)) return;
    items.insert(0, n);
    notifyListeners();
    onNew?.call(n);
    NotificationService.instance.show(id: n.id, title: n.title, body: n.body);
  }

  Future<void> markAllRead() async {
    for (final n in items) {
      n.read = true;
    }
    notifyListeners();
    try {
      await api.post('/api/notifications/read-all');
    } on ApiException {
      // best effort
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    n.read = true;
    notifyListeners();
    try {
      await api.post('/api/notifications/${n.id}/read');
    } on ApiException {
      // best effort
    }
  }

  void reset() {
    items.clear();
    notifyListeners();
  }
}

final clinic = ClinicStore();
final notifications = NotificationCenter();

/// What to tell the doctor after sending a prescription on WhatsApp.
String whatsAppResultMessage(String? status, String patientName) => status == 'Skipped'
    ? 'Saved. $patientName has not agreed to WhatsApp, so share it another way.'
    : 'Rx is being sent to $patientName on WhatsApp';
