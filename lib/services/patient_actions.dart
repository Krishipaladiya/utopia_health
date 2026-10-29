import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Opens the phone dialer for the patient's number.
Future<void> callPatient(BuildContext context, Patient patient) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(scheme: 'tel', path: '+91${patient.localPhone}');
  final ok = await launchUrl(uri);
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('Cannot place a call on this device. Number: +91 ${patient.localPhone}')),
    );
  }
}
