import 'models.dart';

/// Family member under the patient's mobile number.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.relationship,
    required this.saved,
    required this.visits,
    required this.clinics,
  });

  /// Negative ids are members that only exist as a clinic's record.
  final int id;
  final String name;
  final int age;
  final String gender;
  final String relationship;
  final bool saved;
  final int visits;
  final int clinics;

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as int,
        name: j['name'] as String,
        age: j['age'] as int,
        gender: j['gender'] as String,
        relationship: (j['relationship'] as String?) ?? 'Self',
        saved: (j['saved'] as bool?) ?? true,
        visits: (j['visits'] as int?) ?? 0,
        clinics: (j['clinics'] as int?) ?? 0,
      );
}

class RxItem {
  const RxItem({required this.name, required this.dose, required this.timing, required this.course});

  final String name;
  final String dose;
  final String timing;
  final String course;

  factory RxItem.fromJson(Map<String, dynamic> j) => RxItem(
        name: j['name'] as String,
        dose: j['dose'] as String,
        timing: j['timing'] as String,
        course: j['course'] as String,
      );
}

class MyPrescription {
  const MyPrescription({
    required this.id,
    required this.date,
    required this.memberName,
    required this.doctorName,
    required this.clinicName,
    required this.items,
    required this.notes,
  });

  final int id;
  final DateTime date;
  final String memberName;
  final String doctorName;
  final String clinicName;
  final List<RxItem> items;
  final String notes;

  factory MyPrescription.fromJson(Map<String, dynamic> j) => MyPrescription(
        id: j['id'] as int,
        date: parseUtc(j['createdAt'] as String),
        memberName: j['memberName'] as String,
        doctorName: j['doctorName'] as String,
        clinicName: j['clinicName'] as String,
        items: (j['items'] as List).map((e) => RxItem.fromJson(e as Map<String, dynamic>)).toList(),
        notes: (j['notes'] as String?) ?? '',
      );
}

class LabTest {
  const LabTest({
    required this.id,
    required this.tests,
    required this.status,
    required this.date,
    required this.memberName,
    required this.labName,
    required this.hasReport,
    this.patientPhone = '',
    this.patientAge = 0,
    this.patientGender = '',
    this.notes = '',
  });

  final int id;
  final String tests;
  final String status;
  final DateTime date;
  final String memberName;
  final String labName;
  final bool hasReport;
  final String patientPhone;
  final int patientAge;
  final String patientGender;
  final String notes;

  String get statusLabel => switch (status) {
        'SampleCollected' => 'Sample collected',
        'ReportReady' => 'Report ready',
        _ => 'Ordered',
      };

  factory LabTest.fromJson(Map<String, dynamic> j) => LabTest(
        id: j['id'] as int,
        tests: j['tests'] as String,
        status: j['status'] as String,
        date: parseUtc(j['createdAt'] as String),
        memberName: (j['memberName'] ?? j['patientName']) as String,
        labName: (j['labName'] as String?) ?? 'Lab',
        hasReport: (j['hasReport'] as bool?) ?? false,
        patientPhone: (j['patientPhone'] as String?) ?? '',
        patientAge: (j['patientAge'] as int?) ?? 0,
        patientGender: (j['patientGender'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );
}

/// A token in today's queue, as the patient sees it.
class MyToken {
  const MyToken({
    required this.id,
    required this.number,
    required this.status,
    required this.memberName,
    required this.clinicName,
    required this.ahead,
    required this.waitMinutes,
    this.nowServing,
  });

  final int id;
  final int number;
  final String status;
  final String memberName;
  final String clinicName;
  final int ahead;
  final int waitMinutes;
  final int? nowServing;

  factory MyToken.fromJson(Map<String, dynamic> j) => MyToken(
        id: j['id'] as int,
        number: j['number'] as int,
        status: j['status'] as String,
        memberName: j['memberName'] as String,
        clinicName: j['clinicName'] as String,
        ahead: j['ahead'] as int,
        waitMinutes: j['waitMinutes'] as int,
        nowServing: j['nowServing'] as int?,
      );
}

class MyAppointment {
  const MyAppointment({
    required this.id,
    required this.start,
    required this.status,
    required this.memberName,
    required this.clinicName,
  });

  final int id;
  final DateTime start;
  final String status;
  final String memberName;
  final String clinicName;

  factory MyAppointment.fromJson(Map<String, dynamic> j) => MyAppointment(
        id: j['id'] as int,
        start: DateTime.parse(j['start'] as String),
        status: j['status'] as String,
        memberName: j['memberName'] as String,
        clinicName: j['clinicName'] as String,
      );
}

class ClinicCard {
  const ClinicCard({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.doctorName,
    required this.qualification,
    required this.speciality,
    required this.fee,
    required this.experienceYears,
    required this.waiting,
    required this.waitMinutes,
    this.distanceKm,
    this.lat,
    this.lng,
  });

  final int id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String doctorName;
  final String qualification;
  final String speciality;
  final int fee;
  final int experienceYears;
  final int waiting;
  final int waitMinutes;
  final double? distanceKm;
  final double? lat;
  final double? lng;

  String get place => [address, city].where((x) => x.isNotEmpty).join(', ');

  factory ClinicCard.fromJson(Map<String, dynamic> j) => ClinicCard(
        id: j['id'] as int,
        name: j['name'] as String,
        address: (j['address'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        doctorName: j['doctorName'] as String,
        qualification: (j['qualification'] as String?) ?? '',
        speciality: (j['speciality'] as String?) ?? '',
        fee: (j['fee'] as int?) ?? 0,
        experienceYears: (j['experienceYears'] as int?) ?? 0,
        waiting: (j['waiting'] as int?) ?? 0,
        waitMinutes: (j['waitMinutes'] as int?) ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

class PostMediaRef {
  const PostMediaRef({required this.id, required this.type, required this.name});

  final int id;
  final String type;
  final String name;

  bool get isVideo => type == 'video';
}

class BlogPost {
  const BlogPost({
    required this.id,
    required this.clinicId,
    required this.title,
    required this.body,
    required this.videoUrl,
    required this.published,
    required this.date,
    required this.doctorName,
    required this.clinicName,
    required this.media,
  });

  final int id;
  final int clinicId;
  final String title;
  final String body;
  final String videoUrl;
  final bool published;
  final DateTime date;
  final String doctorName;
  final String clinicName;
  final List<PostMediaRef> media;

  PostMediaRef? get cover => media.where((m) => !m.isVideo).firstOrNull;

  factory BlogPost.fromJson(Map<String, dynamic> j) => BlogPost(
        id: j['id'] as int,
        clinicId: j['clinicId'] as int,
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
        videoUrl: (j['videoUrl'] as String?) ?? '',
        published: (j['published'] as bool?) ?? true,
        date: parseUtc(j['createdAt'] as String),
        doctorName: (j['doctorName'] as String?) ?? '',
        clinicName: (j['clinicName'] as String?) ?? '',
        media: ((j['media'] as List?) ?? const [])
            .map((e) => PostMediaRef(id: e['id'] as int, type: e['type'] as String, name: (e['name'] as String?) ?? ''))
            .toList(),
      );
}

class Camp {
  const Camp({
    required this.id,
    required this.clinicName,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.venue,
    required this.city,
    required this.details,
    required this.fee,
    required this.contactPhone,
    this.lat,
    this.lng,
    this.distanceKm,
  });

  final int id;
  final String clinicName;
  final String title;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String venue;
  final String city;
  final String details;
  final int fee;
  final String contactPhone;
  final double? lat;
  final double? lng;
  final double? distanceKm;

  factory Camp.fromJson(Map<String, dynamic> j) => Camp(
        id: j['id'] as int,
        clinicName: (j['clinicName'] as String?) ?? '',
        title: j['title'] as String,
        kind: (j['kind'] as String?) ?? 'Other',
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        venue: (j['venue'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        details: (j['details'] as String?) ?? '',
        fee: (j['fee'] as int?) ?? 0,
        contactPhone: (j['contactPhone'] as String?) ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      );
}

/// Prescription sent to a partner clinic.
class FacilityRx {
  const FacilityRx({
    required this.id,
    required this.date,
    required this.patientName,
    required this.patientPhone,
    required this.patientAge,
    required this.patientGender,
    required this.items,
    required this.notes,
    required this.status,
  });

  final int id;
  final DateTime date;
  final String patientName;
  final String patientPhone;
  final int patientAge;
  final String patientGender;
  final List<RxItem> items;
  final String notes;
  final String status;

  factory FacilityRx.fromJson(Map<String, dynamic> j) => FacilityRx(
        id: j['id'] as int,
        date: parseUtc(j['createdAt'] as String),
        patientName: j['patientName'] as String,
        patientPhone: j['patientPhone'] as String,
        patientAge: j['patientAge'] as int,
        patientGender: j['patientGender'] as String,
        items: (j['items'] as List).map((e) => RxItem.fromJson(e as Map<String, dynamic>)).toList(),
        notes: (j['notes'] as String?) ?? '',
        status: j['status'] as String,
      );
}

class Facility {
  const Facility({required this.id, required this.kind, required this.name, required this.phone, required this.address, required this.city});

  final int id;
  final String kind;
  final String name;
  final String phone;
  final String address;
  final String city;

  bool get isLab => kind == 'lab';

  factory Facility.fromJson(Map<String, dynamic> j) => Facility(
        id: j['id'] as int,
        kind: j['kind'] as String,
        name: j['name'] as String,
        phone: (j['phone'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
      );
}

class TeamPerson {
  const TeamPerson({required this.id, required this.name, required this.phone, required this.role, this.facilityName, this.facilityId, this.email = ''});

  final int id;
  final String name;
  final String phone;
  final String role;
  final String? facilityName;
  final int? facilityId;
  final String email;

  String get roleLabel => switch (role) {
        'clinic' => 'Partner clinic',
        'lab' => 'Laboratory',
        _ => 'Front desk',
      };

  factory TeamPerson.fromJson(Map<String, dynamic> j) => TeamPerson(
        id: j['id'] as int,
        name: j['name'] as String,
        phone: j['phone'] as String,
        role: j['role'] as String,
        facilityName: j['facilityName'] as String?,
        facilityId: j['facilityId'] as int?,
        email: (j['email'] as String?) ?? '',
      );
}

/// One account behind a mobile number, for the login chooser.
class LoginChoice {
  const LoginChoice({required this.role, required this.id, required this.name, required this.place, this.phone});

  final String role;
  final int? id;
  final String name;
  final String place;

  /// Set for patient accounts found by email (one per mobile number).
  final String? phone;

  factory LoginChoice.fromJson(Map<String, dynamic> j) => LoginChoice(
        role: j['role'] as String,
        id: j['id'] as int?,
        name: j['name'] as String,
        place: j['place'] as String,
        phone: j['phone'] as String?,
      );
}

/// A PIN saved on this phone for quick login.
class SavedPin {
  const SavedPin({required this.pinId, required this.name, required this.role});

  final int pinId;
  final String name;
  final String role;

  Map<String, dynamic> toJson() => {'pinId': pinId, 'name': name, 'role': role};

  factory SavedPin.fromJson(Map<String, dynamic> j) =>
      SavedPin(pinId: j['pinId'] as int, name: j['name'] as String, role: j['role'] as String);
}
