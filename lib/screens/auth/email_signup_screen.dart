import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'add_phone_screen.dart';
import 'auth_widgets.dart';
import 'pin_screens.dart';
import 'social_buttons.dart';
import '../../widgets/legal.dart';

/// Doctor sign-up while SMS is not connected: name + email code makes the
/// account and clinic at once; the mobile number is added next.
class EmailSignupScreen extends StatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _codeStep = false;
  bool _sending = false;
  String? _error;
  String? _devCode;

  bool get _valid =>
      _name.text.trim().length >= 3 && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<String?> _send() async {
    try {
      _devCode = await auth.sendEmailOtp(_email.text.trim());
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await _send();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      _codeStep = error == null;
    });
  }

  Future<String?> _verify(String code) async {
    try {
      final needsPhone = await auth.signupEmail(_email.text.trim(), code, _name.text.trim());
      if (!mounted) return null;
      if (needsPhone) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AddPhoneScreen()),
          (_) => false,
        );
      } else {
        await finishLogin(context);
      }
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthHeading(
              title: _codeStep ? 'Check your email' : 'Create your account',
              subtitle: _codeStep
                  ? 'Enter the 6-digit code we sent.'
                  : 'Start in seconds. Your clinic is set up automatically.',
            ),
            const SizedBox(height: 16),
            if (!_codeStep) ...[
              const SocialButtons(caption: 'or sign up with email', dividerFirst: false),
              const FieldLabel('Your name'),
              AuthTextField(
                controller: _name,
                hint: 'Dr. Asha Mehta',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                onChanged: (_) => setState(() {}),
              ),
              const FieldLabel('Email'),
              AuthTextField(
                controller: _email,
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                ),
              PrimaryButton(
                label: _sending ? 'Sending code...' : 'Send code',
                icon: Icons.send_rounded,
                onPressed: _valid && !_sending ? _start : null,
              ),
            ] else
              OtpPanel(
                sentTo: _email.text.trim(),
                channel: 'email',
                devCode: _devCode,
                onChangeNumber: () => setState(() => _codeStep = false),
                onResend: _send,
                onSubmit: _verify,
              ),
            const SizedBox(height: 16),
            const LegalAgreementText(prefix: 'By creating an account you agree to the '),
          ],
        ),
      ),
    );
  }
}
