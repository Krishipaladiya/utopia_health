import 'package:flutter/material.dart';

import '../home_shell.dart';
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
      : const HomeShell();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => next),
    (_) => false,
  );
}
