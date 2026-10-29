import 'models.dart';

/// Result of looking up a mobile number.
class PatientLookup {
  const PatientLookup({required this.inClinic, required this.network});

  final List<Patient> inClinic;

  /// The same number at other doctors' clinics.
  final List<NetworkPatient> network;

  bool get isEmpty => inClinic.isEmpty && network.isEmpty;

  factory PatientLookup.fromJson(Map<String, dynamic> j) => PatientLookup(
        inClinic: (j['inClinic'] as List).map((e) => Patient.fromJson(e as Map<String, dynamic>)).toList(),
        network: (j['network'] as List).map((e) => NetworkPatient.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class NetworkPatient {
  const NetworkPatient({
    required this.name,
    required this.age,
    required this.gender,
    required this.email,
    required this.address,
    required this.relationship,
    required this.otherDiseases,
    required this.doctorName,
    required this.clinicName,
  });

  final String name;
  final int age;
  final String gender;
  final String email;
  final String address;
  final String relationship;
  final String otherDiseases;
  final String doctorName;
  final String clinicName;

  factory NetworkPatient.fromJson(Map<String, dynamic> j) => NetworkPatient(
        name: j['name'] as String,
        age: j['age'] as int,
        gender: j['gender'] as String,
        email: (j['email'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        relationship: (j['relationship'] as String?) ?? 'Self',
        otherDiseases: (j['otherDiseases'] as String?) ?? '',
        doctorName: j['doctorName'] as String,
        clinicName: j['clinicName'] as String,
      );
}

/// A doctor the patient visits (doctor tracking).
class DoctorVisit {
  const DoctorVisit({
    required this.doctorName,
    required this.speciality,
    required this.clinicName,
    required this.firstVisit,
    required this.lastVisit,
    required this.visits,
    required this.isYou,
  });

  final String doctorName;
  final String speciality;
  final String clinicName;
  final DateTime firstVisit;
  final DateTime? lastVisit;
  final int visits;
  final bool isYou;

  factory DoctorVisit.fromJson(Map<String, dynamic> j) => DoctorVisit(
        doctorName: j['doctorName'] as String,
        speciality: (j['speciality'] as String?) ?? '',
        clinicName: j['clinicName'] as String,
        firstVisit: parseUtc(j['firstVisit'] as String),
        lastVisit: j['lastVisit'] == null ? null : parseUtc(j['lastVisit'] as String),
        visits: j['visits'] as int,
        isYou: j['isYou'] as bool,
      );
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.relationship,
  });

  final int id;
  final String name;
  final int age;
  final String gender;
  final String relationship;

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: j['id'] as int,
        name: j['name'] as String,
        age: j['age'] as int,
        gender: j['gender'] as String,
        relationship: (j['relationship'] as String?) ?? '',
      );
}

class PatientProfile {
  const PatientProfile({
    required this.patient,
    required this.family,
    required this.doctors,
    required this.visits,
    required this.prescriptions,
    required this.files,
  });

  final Patient patient;
  final List<FamilyMember> family;
  final List<DoctorVisit> doctors;
  final int visits;
  final int prescriptions;
  final int files;

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
        patient: Patient.fromJson(j['patient'] as Map<String, dynamic>),
        family: (j['family'] as List).map((e) => FamilyMember.fromJson(e as Map<String, dynamic>)).toList(),
        doctors: (j['doctors'] as List).map((e) => DoctorVisit.fromJson(e as Map<String, dynamic>)).toList(),
        visits: j['visits'] as int,
        prescriptions: j['prescriptions'] as int,
        files: j['files'] as int,
      );
}

/// "3 mo", "1 yr 2 mo": how long someone has been a patient.
String durationSince(DateTime? from) {
  if (from == null) return '-';
  final days = DateTime.now().difference(from).inDays;
  if (days < 1) return 'Today';
  if (days < 30) return '$days d';
  final months = days ~/ 30;
  if (months < 12) return '$months mo';
  final years = months ~/ 12;
  final rest = months % 12;
  return rest == 0 ? '$years yr' : '$years yr $rest mo';
}
