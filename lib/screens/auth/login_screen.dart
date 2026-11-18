import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import 'auth_widgets.dart';
import 'email_signup_screen.dart';
import 'pin_screens.dart';
import 'register_screen.dart';
import 'social_buttons.dart';
import '../../widgets/legal.dart';

/// One login for every role. While SMS is not connected the email code is the
/// main way in; patients can also use the code their clinic sent on WhatsApp.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _smsAvailable = false;
  String _mode = 'email'; // email | phone
  bool _codeStep = false;
  bool _sending = false;
  String? _error;
  String? _devCode;

  bool get _validPhone => _phone.text.length == 10;
  bool get _validEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  @override
  void initState() {
    super.initState();
    auth.methods().then((m) {
      if (!mounted) return;
      setState(() {
        _smsAvailable = m['sms'] == true;
        _mode = _smsAvailable ? 'phone' : 'email';
      });
    });
    AppSession.lastPhone().then((p) {
      if (mounted && p.length == 10 && _phone.text.isEmpty) setState(() => _phone.text = p);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  // ---- sending the code ------------------------------------------------------

  Future<String?> _send() async {
    try {
      _devCode = _mode == 'phone' ? await auth.sendOtp(_phone.text) : await auth.sendEmailOtp(_email.text.trim());
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  Future<void> _sendCode() async {
    if (_sending) return;
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

  // ---- checking the code -----------------------------------------------------

  Future<String?> _verify(String code) async {
    try {
      final choices = _mode == 'phone'
          ? await auth.login(_phone.text, code)
          : await auth.loginEmail(_email.text.trim(), code);
      if (choices != null) {
        if (!mounted) return null;
        final pick = await showAccountChooser(context, choices);
        if (pick == null) return 'Choose an account to continue.';
        _mode == 'phone' ? await auth.select(pick) : await auth.selectEmail(pick);
      }
      if (mounted) await finishLogin(context);
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  Future<void> _clinicCode() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code from your clinic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your clinic sends it on WhatsApp, e.g. K7Q2-XM4P.',
              style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Login code'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Log in')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.loginWithLink(code);
      if (mounted) await finishLogin(context);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    }
  }

  void _switchMode(String mode) => setState(() {
        _mode = mode;
        _codeStep = false;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final sentTo = _mode == 'phone' ? formatPhone(_phone.text) : _email.text.trim();
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthHeading(
              title: _codeStep ? 'Enter the code' : 'Welcome',
              subtitle: _codeStep
                  ? 'We sent a 6-digit code. You will be logged in automatically.'
                  : 'Doctors, clinics, labs and patients log in here.',
            ),
            const SizedBox(height: 20),
            if (_smsAvailable && !_codeStep) ...[
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'email', label: Text('Email'), icon: Icon(Icons.mail_outline_rounded)),
                    ButtonSegment(value: 'phone', label: Text('Mobile'), icon: Icon(Icons.phone_iphone_rounded)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _switchMode(s.first),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (!_codeStep) ...[
              if (_mode == 'phone') ...[
                const FieldLabel('Mobile number'),
                PhoneField(controller: _phone, onChanged: (v) {
                  setState(() => _error = null);
                  if (v.length == 10) _sendCode();
                }),
              ] else ...[
                const FieldLabel('Email'),
                AuthTextField(
                  controller: _email,
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (_) => setState(() => _error = null),
                ),
              ],
              const SizedBox(height: 10),
              if (_error != null)
                Text(_error!, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
              if (_mode == 'email') ...[
                const SizedBox(height: 8),
                PrimaryButton(
                  label: _sending ? 'Sending code...' : 'Send code',
                  icon: Icons.send_rounded,
                  onPressed: _validEmail && !_sending ? _sendCode : null,
                ),
              ] else if (_sending)
                Text('Sending code...', style: AppText.inter(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600))
              else if (_validPhone)
                TextButton.icon(onPressed: _sendCode, icon: const Icon(Icons.sms_outlined, size: 18), label: const Text('Send code')),
            ] else
              OtpPanel(
                sentTo: sentTo,
                channel: _mode == 'phone' ? 'SMS' : 'email',
                devCode: _devCode,
                onChangeNumber: () => setState(() => _codeStep = false),
                onResend: _send,
                onSubmit: _verify,
              ),
            if (!_codeStep) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: _clinicCode,
                  icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                  label: const Text('Patient? Use the code from your clinic'),
                ),
              ),
              const SocialButtons(),
              const SizedBox(height: 12),
              const LegalAgreementText(),
            ],
            const SizedBox(height: 22),
            Center(
              child: Text.rich(
                TextSpan(
                  style: AppText.inter(fontSize: 14, color: AppColors.textMuted),
                  children: [
                    const TextSpan(text: 'New doctor?  '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _smsAvailable ? const RegisterScreen() : const EmailSignupScreen(),
                          ),
                        ),
                        child: Text(
                          'Create account',
                          style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
