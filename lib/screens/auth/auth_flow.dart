import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../facility/facility_shell.dart';
import '../home_shell.dart';
import '../patient/patient_shell.dart';
import '../slot_setup_screen.dart';

/// After a successful login or registration. A newly registered doctor first
/// sets up appointment slots, then lands on Home.
void enterApp(BuildContext context, {bool newlyRegistered = false}) {
  // Captured now: this screen is removed from the tree by the push below.
  final navigator = Navigator.of(context);

  final Widget next = newlyRegistered
      ? SlotSetupScreen(
          onboarding: true,
          onDone: () => navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeShell()),
            (_) => false,
          ),
        )
      : homeForRole();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => next),
    (_) => false,
  );
}

/// The first screen for whoever is signed in: each role has its own app.
Widget homeForRole() {
  if (session.isPatient) return const PatientShell();
  if (session.isFacility) return const FacilityShell();
  return const HomeShell();
}
