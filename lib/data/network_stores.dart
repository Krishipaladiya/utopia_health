import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/network.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/session.dart';
import 'reminders.dart';

/// Notification inbox for patients and partner clinics / labs.
class InboxCenter extends ChangeNotifier {
  final List<AppNotification> items = [];

  /// Called with each live item so the UI can show the animated banner.
  void Function(AppNotification)? onNew;

  int get unread => items.where((n) => !n.read).length;

  String get _base => session.isPatient ? '/api/me' : '/api/facility';

  Future<void> load() async {
    try {
      final data = await api.get('$_base/notifications') as Map<String, dynamic>;
      items
        ..clear()
        ..addAll((data['items'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } on ApiException {
      // keep what we have
    }
  }

  void addFromServer(Map<String, dynamic> json) {
    final n = AppNotification.fromJson(json);
    if (items.any((x) => x.id == n.id)) return;
    items.insert(0, n);
    notifyListeners();
    onNew?.call(n);
    NotificationService.instance.show(id: 900000 + n.id, title: n.title, body: n.body);
  }

  Future<void> markAllRead() async {
    for (final n in items) {
      n.read = true;
    }
    notifyListeners();
    try {
      await api.post('$_base/notifications/read-all');
    } on ApiException {
      // best effort
    }
  }

  void reset() {
    items.clear();
    notifyListeners();
  }
}

/// Everything the patient app shows: members, records, live tokens, bookings.
class PatientStore extends ChangeNotifier {
  List<Member> members = [];
  List<MyPrescription> prescriptions = [];
  List<LabTest> labTests = [];
  List<MyToken> tokens = [];
  List<MyAppointment> appointments = [];

  /// The patient agreed that their doctors may share notes and visit history.
  bool sharing = false;
  bool loaded = false;
  String? error;

  Future<void> loadAll() async {
    await Future.wait([refreshMembers(), refreshRecords(), refreshQueue(), refreshAppointments(), inbox.load(), _loadSharing()]);
    loaded = true;
    notifyListeners();
  }

  Future<void> refreshMembers() async {
    try {
      final data = await api.get('/api/me') as Map<String, dynamic>;
      members = (data['members'] as List).map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
      error = null;
    } on ApiException catch (e) {
      error = e.friendly;
    }
    notifyListeners();
  }

  Future<void> refreshRecords() async {
    try {
      final data = await api.get('/api/me/records') as Map<String, dynamic>;
      prescriptions = (data['prescriptions'] as List)
          .map((e) => MyPrescription.fromJson(e as Map<String, dynamic>))
          .toList();
      labTests = (data['labOrders'] as List).map((e) => LabTest.fromJson(e as Map<String, dynamic>)).toList();
      await medicineReminders.sync(prescriptions);
    } on ApiException catch (e) {
      error = e.friendly;
    }
    notifyListeners();
  }

  Future<void> refreshQueue() async {
    try {
      final data = await api.get('/api/me/queue') as List;
      tokens = data.map((e) => MyToken.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      // keep
    }
    notifyListeners();
  }

  Future<void> refreshAppointments() async {
    try {
      final data = await api.get('/api/me/appointments') as List;
      appointments = data.map((e) => MyAppointment.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      // keep
    }
    notifyListeners();
  }

  Future<void> _loadSharing() async {
    try {
      final data = await api.get('/api/me/sharing') as Map<String, dynamic>;
      sharing = data['granted'] == true;
    } on ApiException {
      // keep
    }
  }

  Future<void> setSharing(bool on) async {
    final data = await api.put('/api/me/sharing', {'granted': on}) as Map<String, dynamic>;
    sharing = data['granted'] == true;
    notifyListeners();
  }

  Future<void> addMember(String name, int age, String gender, String relationship) async {
    final data = await api.post('/api/me/members', {
      'name': name,
      'age': age,
      'gender': gender,
      'relationship': relationship,
    }) as List;
    members = data.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> deleteMember(Member m) async {
    final data = await api.delete('/api/me/members/${m.id}') as List;
    members = data.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> requestAppointment(int clinicId, DateTime start, Member member, String reason) async {
    await api.post('/api/me/appointments', {
      'clinicId': clinicId,
      'start': _local(start),
      'memberId': member.id,
      'reason': reason,
    });
    await refreshAppointments();
  }

  /// Check in by clinic QR code. Returns the token details.
  Future<Map<String, dynamic>> checkIn(String code, Member member) async {
    final data = await api.post('/api/me/checkin', {'code': code, 'memberId': member.id}) as Map<String, dynamic>;
    await refreshQueue();
    return data;
  }

  void reset() {
    members = [];
    prescriptions = [];
    labTests = [];
    tokens = [];
    appointments = [];
    loaded = false;
    inbox.reset();
    notifyListeners();
  }
}

/// Partner clinic: prescriptions sent to it. Lab: test orders.
class FacilityStore extends ChangeNotifier {
  List<FacilityRx> prescriptions = [];
  List<LabTest> labOrders = [];
  bool loaded = false;
  String? error;

  Future<void> loadAll() async {
    await Future.wait([refresh(), inbox.load()]);
    loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      if (session.isLab) {
        final data = await api.get('/api/facility/lab-orders') as List;
        labOrders = data.map((e) => LabTest.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        final data = await api.get('/api/facility/prescriptions') as List;
        prescriptions = data.map((e) => FacilityRx.fromJson(e as Map<String, dynamic>)).toList();
      }
      error = null;
    } on ApiException catch (e) {
      error = e.friendly;
    }
    notifyListeners();
  }

  Future<void> setRxStatus(FacilityRx rx, String status) async {
    await api.post('/api/facility/prescriptions/${rx.id}/status', {'status': status});
    await refresh();
  }

  Future<void> setLabStatus(LabTest o, String status) async {
    await api.post('/api/facility/lab-orders/${o.id}/status', {'status': status});
    await refresh();
  }

  Future<void> uploadReport(LabTest o, PickedUpload file) async {
    await api.uploadPicked('/api/facility/lab-orders/${o.id}/report', file);
    await refresh();
  }

  void reset() {
    prescriptions = [];
    labOrders = [];
    loaded = false;
    inbox.reset();
    notifyListeners();
  }
}

/// Doctor: team, partner clinics and labs, clinic details.
class TeamStore extends ChangeNotifier {
  List<Facility> facilities = [];
  List<TeamPerson> members = [];
  Map<String, dynamic>? clinicInfo;

  List<Facility> get partnerClinics => facilities.where((f) => !f.isLab).toList();
  List<Facility> get labs => facilities.where((f) => f.isLab).toList();

  Future<void> load() async {
    final data = await api.get('/api/team') as Map<String, dynamic>;
    facilities = (data['facilities'] as List).map((e) => Facility.fromJson(e as Map<String, dynamic>)).toList();
    members = (data['members'] as List).map((e) => TeamPerson.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  Future<void> loadClinic() async {
    clinicInfo = await api.get('/api/team/clinic') as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> saveClinic(Map<String, dynamic> info) async {
    clinicInfo = await api.put('/api/team/clinic', info) as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> addFacility(String kind, String name, String phone, String address, String city) async {
    await api.post('/api/team/facilities', {
      'kind': kind,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
    });
    await load();
  }

  Future<void> removeFacility(Facility f) async {
    await api.delete('/api/team/facilities/${f.id}');
    await load();
  }

  Future<void> addMember(String name, String phone, String role, int? facilityId, {String email = ''}) async {
    await api.post('/api/team/members', {
      'name': name,
      'phone': phone,
      'role': role,
      'facilityId': facilityId,
      'email': email,
    });
    await load();
  }

  Future<void> removeMember(TeamPerson m) async {
    await api.delete('/api/team/members/${m.id}');
    await load();
  }

  Future<void> sendRxToClinic(int prescriptionId, Facility f) async {
    await api.post('/api/prescriptions/$prescriptionId/send-to-facility', {'facilityId': f.id});
  }

  Future<void> orderLab(Patient patient, Facility lab, String tests, String notes) async {
    await api.post('/api/patients/${patient.dbId}/lab-orders', {
      'facilityId': lab.id,
      'tests': tests,
      'notes': notes,
    });
  }

  Future<List<LabTest>> labOrdersFor(Patient patient) async {
    final data = await api.get('/api/patients/${patient.dbId}/lab-orders') as List;
    return data.map((e) => LabTest.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Clinic time without a time zone, as the API expects for appointments.
String _local(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}T${_pad2(d.hour)}:${_pad2(d.minute)}:00';
String _pad2(int n) => n.toString().padLeft(2, '0');

final inbox = InboxCenter();
final patientStore = PatientStore();
final facilityStore = FacilityStore();
final teamStore = TeamStore();
