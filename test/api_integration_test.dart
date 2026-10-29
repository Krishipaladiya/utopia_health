// Integration test: the real Flutter data layer against the real .NET API.
// Start the API first:  dotnet run --project backend/UtopiaHealth.Api (port 5080, Development)
// Run:                  flutter test test/api_integration_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_health/data/appointments_store.dart';
import 'package:utopia_health/data/clinic_store.dart';
import 'package:utopia_health/data/doctor_store.dart';
import 'package:utopia_health/models/models.dart';
import 'package:utopia_health/services/api_client.dart';
import 'package:utopia_health/services/auth_service.dart';
import 'package:utopia_health/services/realtime_service.dart';

Future<void> eventually(bool Function() check, {int seconds = 5, String? what}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    if (check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for ${what ?? 'condition'}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding blocks real network calls (answers 400); allow them here.
  HttpOverrides.global = null;
  // flutter_test pretends to be Android (emulator address); use the PC's own.
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  tearDownAll(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues({});

  final phone = '9${DateTime.now().millisecondsSinceEpoch.toString().substring(4, 13)}';
  late int clinicId;

  test('register request, team onboarding, then log in', () async {
    final email = 'doc$phone@example.com';
    const adminHeaders = {'X-Admin-Key': 'dev-admin-key', 'Content-Type': 'application/json'};

    // Doctor: verify mobile and email, then send the request.
    expect(await auth.sendOtp(phone), isNotNull);
    final phoneProof = await auth.verifyContact('phone', phone, '123456');
    expect(await auth.sendEmailOtp(email), isNotNull);
    final emailProof = await auth.verifyContact('email', email, '123456');
    await expectLater(
      auth.verifyContact('phone', phone, '12'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_otp')),
    );
    await auth.requestRegistration(phoneProof: phoneProof, emailProof: emailProof);

    // Until our team sets the clinic up, login says the request is pending.
    await expectLater(
      auth.login(phone, '123456'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'registration_pending')),
    );

    // Our team onboards the doctor (admin API).
    final list = jsonDecode(
      (await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/registrations?status=New'),
        headers: adminHeaders,
      ))
          .body,
    ) as List;
    final request = list.firstWhere((r) => r['email'] == email);
    final onboard = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/registrations/${request['id']}/onboard'),
      headers: adminHeaders,
      body: jsonEncode({
        'name': 'Dr. Test Doctor',
        'clinicName': 'Test Clinic',
        'qualification': 'BHMS',
        'regNo': 'T-1',
        'speciality': 'Homeopathy',
      }),
    );
    expect(onboard.statusCode, 200, reason: onboard.body);
    clinicId = jsonDecode(onboard.body)['clinicId'] as int;

    // Now the doctor logs in with the mobile code.
    await auth.login(phone, '123456');
    expect(api.hasSession, isTrue);
    expect(doctorProfile.clinic, 'Test Clinic');
    expect(doctorProfile.name, 'Dr. Test Doctor');

    await api.clearSession();
    await expectLater(
      auth.login('9000000009', '123456'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_registered')),
    );
    await auth.login(phone, '123456');
  });

  test('profile and slots save to the server', () async {
    doctorProfile.update(fee: 450, bio: 'Updated bio');
    await doctorProfile.save();
    doctorProfile.update(fee: 1);
    await doctorProfile.load();
    expect(doctorProfile.fee, 450);

    await slotConfig.load();
    expect(slotConfig.days[1]!.sessions.length, 2);
    slotConfig.setSlotMinutes(20);
    slotConfig.setCapacity(2);
    await slotConfig.save();
    slotConfig.setSlotMinutes(5);
    await slotConfig.load();
    expect(slotConfig.slotMinutes, 20);
    expect(slotConfig.perHour, 6);
  });

  test('queue, patients, prescriptions and finance', () async {
    await clinic.loadAll();
    expect(clinic.patients, isEmpty);
    expect(clinic.current, isNull);

    final family = await clinic.addPatient(
      name: 'Rajesh Kumar',
      phone: '9825014820',
      age: 38,
      gender: 'Male',
      complaint: 'Gastric headache',
      addToQueue: true,
    );
    expect(family, isNull);
    expect(clinic.upcoming.single.patient.name, 'Rajesh Kumar');
    expect(clinic.patientTotal, 1);

    final kid = await clinic.addPatient(
      name: 'Master Aarav',
      phone: '9825014820',
      age: 6,
      gender: 'Male',
      addToQueue: true,
    );
    expect(kid, 'Rajesh Kumar'); // family folder
    expect(clinic.patientWithPhone('+91 98250 14820'), isNotNull);

    await clinic.callNext(clinic.upcoming.first);
    expect(clinic.current?.patient.name, 'Rajesh Kumar');
    expect(clinic.upcoming.length, 1);

    final rajesh = clinic.current!.patient;
    final status = await clinic.prescribe(rajesh, [
      {'name': 'Lycopodium 200CH', 'dose': '4 Globules', 'timing': 'Dawn, Dusk', 'course': '14 Days'},
    ]);
    expect(status, 'Queued'); // sent by the background worker
    final records = await clinic.records(rajesh, 'Test Clinic');
    expect(records.single.kind, RecordKind.prescription);
    expect(records.single.body, contains('Lycopodium 200CH'));
    expect(records.single.delivery, anyOf('Queued', 'Sent'));
    expect(await clinic.resendPrescription(records.single.id), 'Queued');

    // A patient who has not agreed to WhatsApp is skipped, and the app says so.
    await clinic.addPatient(
      name: 'No Consent',
      phone: '9825011111',
      age: 40,
      gender: 'Male',
      addToQueue: false,
      whatsAppConsent: false,
    );
    final noConsent = clinic.patients.firstWhere((p) => p.name == 'No Consent');
    expect(noConsent.whatsAppConsent, isFalse);
    final skipped = await clinic.prescribe(noConsent, [
      {'name': 'Arnica 30CH', 'dose': '4 Pills', 'timing': 'Noon', 'course': 'As advised'},
    ]);
    expect(skipped, 'Skipped');
    expect(whatsAppResultMessage(skipped, 'No Consent'), contains('not agreed'));
    await clinic.setWhatsAppConsent(noConsent, true);
    expect(clinic.patients.firstWhere((p) => p.name == 'No Consent').whatsAppConsent, isTrue);
    expect(clinic.patients.firstWhere((p) => p.dbId == rajesh.dbId).lastRemedy, 'Lycopodium 200CH');

    await clinic.completeCurrent();
    expect(clinic.current, isNull);
    expect(clinic.completedToday, 1);

    await clinic.addFee(patientName: 'Rajesh Kumar', amount: 300, mode: 'UPI (GPay)');
    await clinic.addSpend(title: 'Rent', amount: 100, mode: 'Cash');
    expect(clinic.netBalance, 200);
    expect(clinic.todayIncome, 300);
    expect(clinic.ledger.first.title, 'Rent');
    expect(clinic.ledger.first.isIncome, isFalse);
    await clinic.setPeriod('week');
    expect(clinic.summary.income, 300);

    await notifications.load();
    expect(notifications.items.any((n) => n.kind == NotificationKind.prescription), isTrue);
  });

  test('appointments: book, double-booking blocked, check-in, missed, cancel', () async {
    // Patients and slot setup come from the earlier tests (20 min slots, 2 per slot).
    await clinic.loadAll();
    await slotConfig.load();
    final rajesh = clinic.patients.firstWhere((p) => p.name == 'Rajesh Kumar');
    final aarav = clinic.patients.firstWhere((p) => p.name == 'Master Aarav');

    // First open day from tomorrow on (Sunday is off by default).
    var day = DateTime.now().add(const Duration(days: 1));
    day = DateTime(day.year, day.month, day.day);
    var slots = await appointments.availableSlots(day);
    while (slots.isEmpty) {
      day = day.add(const Duration(days: 1));
      slots = await appointments.availableSlots(day);
    }
    expect(slots.first.capacity, 2);
    expect(slots.first.available, 2);

    DateTime at(int min) => DateTime(day.year, day.month, day.day, min ~/ 60, min % 60);
    final first = slots.first.startMin;

    await appointments.selectDate(day);
    await appointments.book(rajesh, at(first));
    await appointments.book(aarav, at(first));
    expect(appointments.selected.length, 2);

    // capacity 2 is now used up
    await expectLater(
      appointments.book(rajesh, at(first)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'slot_full')),
    );
    await expectLater(
      appointments.book(rajesh, at(first + 7)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_a_slot')),
    );
    final after = await appointments.availableSlots(day);
    expect(after.first.available, 0);

    // past times are refused
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await expectLater(
      appointments.book(rajesh, DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 0)),
      throwsA(isA<ApiException>()),
    );

    // mark one missed, cancel the other -> slot is free again
    final a1 = appointments.selected.firstWhere((a) => a.patient.name == 'Rajesh Kumar');
    final a2 = appointments.selected.firstWhere((a) => a.patient.name == 'Master Aarav');
    await appointments.markMissed(a1);
    await appointments.cancel(a2);
    expect(appointments.selected.firstWhere((a) => a.id == a1.id).status, AppointmentStatus.missed);
    expect(appointments.selected.firstWhere((a) => a.id == a2.id).status, AppointmentStatus.cancelled);
    expect((await appointments.availableSlots(day)).first.available, 2);

    // check-in: the appointment joins today's queue
    final queueBefore = clinic.upcoming.length;
    await appointments.book(aarav, at(first));
    final booked = appointments.selected.firstWhere((a) => a.status == AppointmentStatus.booked);
    await appointments.checkIn(booked);
    expect(appointments.selected.firstWhere((a) => a.id == booked.id).status, AppointmentStatus.done);
    expect(clinic.upcoming.length, queueBefore + 1);
  });

  test('remedies load from the API', () async {
    final data = await api.get('/api/remedies', query: {'q': 'nux'}) as Map<String, dynamic>;
    final remedies = (data['items'] as List).map((e) => Remedy.fromJson(e as Map<String, dynamic>)).toList();
    expect(remedies.single.name, 'Nux Vomica');
    expect(data['total'], 11);
  });

  test('live: changes made elsewhere appear without refreshing', () async {
    await RealtimeService.instance.start();
    expect(RealtimeService.instance.connected.value, isTrue);

    final shown = <AppNotification>[];
    notifications.onNew = shown.add;
    final beforeQueue = clinic.upcoming.length;
    final beforeUnread = notifications.unread;

    // A second device (raw HTTP, not our store) changes the data.
    final other = http.Client();
    Future<void> call(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
      final res = await other.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {'Content-Type': 'application/json', ...?headers},
        body: jsonEncode(body),
      );
      expect(res.statusCode, 200, reason: res.body);
    }

    await call(
      '/api/patients',
      {'name': 'Live Patient', 'phone': '9000000042', 'age': 30, 'gender': 'Female', 'addToQueue': true},
      headers: {'Authorization': 'Bearer ${api.token}'},
    );
    await eventually(() => clinic.upcoming.length == beforeQueue + 1, what: 'queue.changed');

    await call(
      '/api/webhooks/upi',
      {'clinicId': clinicId, 'patientName': 'Sunita Devi', 'amount': 500, 'mode': 'PhonePe'},
      headers: {'X-Webhook-Secret': 'dev-webhook-secret'},
    );
    await eventually(() => shown.any((n) => n.kind == NotificationKind.payment), what: 'notification.created');
    expect(notifications.unread, beforeUnread + 1);
    await eventually(() => clinic.ledger.first.title == 'Sunita Devi', what: 'ledger.changed');
    expect(clinic.todayIncome, 800);

    // A booking made on another device refreshes the appointments store.
    final beforeAppts = appointments.today.length + appointments.selected.length;
    final live = clinic.patients.firstWhere((p) => p.name == 'Live Patient', orElse: () => clinic.patients.first);
    final slotsToday = await appointments.availableSlots(DateTime.now());
    final future = slotsToday.where((s) {
      final t = DateTime.now();
      return DateTime(t.year, t.month, t.day, s.startMin ~/ 60, s.startMin % 60).isAfter(t);
    });
    if (future.isNotEmpty) {
      final m = future.first.startMin;
      final t = DateTime.now();
      await call(
        '/api/appointments',
        {'patientId': live.dbId, 'start': apiDateTime(DateTime(t.year, t.month, t.day, m ~/ 60, m % 60))},
        headers: {'Authorization': 'Bearer ${api.token}'},
      );
      await eventually(
        () => appointments.today.length + appointments.selected.length > beforeAppts,
        what: 'appointments.changed',
      );
    }

    await notifications.markAllRead();
    expect(notifications.unread, 0);

    other.close();
    notifications.onNew = null;
    await RealtimeService.instance.stop();
  });

  test('push token: register, move to another login, remove', () async {
    await api.post('/api/devices', {'token': 'fcm-token-1', 'platform': 'android'});
    // same token again (token refresh) is accepted, not duplicated
    await api.post('/api/devices', {'token': 'fcm-token-1', 'platform': 'android'});
    await api.post('/api/devices/remove', {'token': 'fcm-token-1'});
    // removing something that is not there is fine too
    await api.post('/api/devices/remove', {'token': 'fcm-token-1'});

    final health = await http.get(Uri.parse('${ApiConfig.baseUrl}/health'));
    expect(jsonDecode(health.body)['push'], anyOf('log-only', 'firebase'));
  });

  test('bad session is rejected and reported', () async {
    var kicked = 0;
    api.onUnauthorized = () => kicked++;
    final good = api.token!;
    await api.saveSession('not-a-token');
    await expectLater(api.get('/api/queue'), throwsA(isA<ApiException>()));
    expect(kicked, 1);
    await api.saveSession(good);
    await auth.logout();
    expect(api.hasSession, isFalse);
    expect(clinic.patients, isEmpty);
  });
}
