import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import 'login_screen.dart';

/// "Delete my account": explains what happens for this role, asks the person
/// to type DELETE, then deletes and goes back to the login screen.
Future<void> confirmDeleteAccount(BuildContext context) async {
  final what = switch (session.role) {
    'patient' => 'Your app account will be deleted: saved family members, PIN, notifications and login links.\n\n'
        'Prescriptions and reports kept by your clinics stay with them, as medical records must be kept by law. '
        'Ask a clinic if you want them removed there.',
    'doctor' => 'Your login is removed at once and your clinic is closed. Front desk, partner clinic and lab logins '
        'of your clinic stop working.\n\nPatient medical records are kept as the law requires; our team will contact you to finish.',
    _ => 'Your login is removed at once. The clinic keeps its records.',
  };
  final typed = TextEditingController();
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 36),
        title: const Text('Delete account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what, style: AppText.inter(fontSize: 13.5, height: 1.45)),
              const SizedBox(height: 14),
              Text('This cannot be undone. Type DELETE to confirm.', style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: typed,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'DELETE'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: typed.text.trim().toUpperCase() == 'DELETE' ? () => Navigator.pop(context, true) : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete account'),
          ),
        ],
      ),
    ),
  );
  if (yes != true || !context.mounted) return;

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await auth.deleteAccount();
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    messenger.showSnackBar(const SnackBar(content: Text('Your account was deleted.')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
  }
}

/// The red "Delete account" row used on profile / settings screens.
class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => confirmDeleteAccount(context),
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      icon: const Icon(Icons.delete_outline_rounded, size: 20),
      label: const Text('Delete account'),
    );
  }
}
