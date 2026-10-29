import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'auth_flow.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';
import 'social_buttons.dart';

/// Clinic login: mobile number -> code sent by itself -> logs in by itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  bool _otpStep = false;
  bool _sending = false;
  String? _error;
  String? _devCode;

  bool get _validPhone => _phone.text.length == 10;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<String?> _send() async {
    try {
      _devCode = await auth.sendOtp(_phone.text);
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  /// Runs by itself as soon as the 10th digit is typed.
  Future<void> _sendOtp() async {
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
      _otpStep = error == null;
    });
  }

  void _onPhoneChanged(String value) {
    setState(() => _error = null);
    if (value.length == 10) _sendOtp();
  }

  Future<String?> _verify(String code) async {
    try {
      await auth.login(_phone.text, code);
      if (mounted) enterApp(context);
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const AuthLogo(),
          const SizedBox(height: 32),
          AuthHeading(
            title: _otpStep ? 'Verify your number' : 'Welcome back',
            subtitle: _otpStep
                ? 'Enter the 6-digit code. You will be logged in automatically.'
                : 'Enter your mobile number. We will send a code by SMS.',
          ),
          const SizedBox(height: 24),
          if (!_otpStep) ...[
            const FieldLabel('Mobile number'),
            PhoneField(controller: _phone, onChanged: _onPhoneChanged),
            const SizedBox(height: 10),
            if (_sending)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sending code...',
                    style: AppText.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              )
            else if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppText.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  if (_validPhone)
                    TextButton(onPressed: _sendOtp, child: const Text('Try again')),
                ],
              )
            else if (_validPhone)
              TextButton(onPressed: _sendOtp, child: const Text('Send code again'))
            else
              Text(
                'The code is sent as soon as you enter all 10 digits.',
                style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
              ),
          ] else
            OtpPanel(
              sentTo: formatPhone(_phone.text),
              channel: 'SMS',
              devCode: _devCode,
              onChangeNumber: () => setState(() => _otpStep = false),
              onResend: _send,
              onSubmit: _verify,
            ),
          if (!_otpStep) ...[
            const SizedBox(height: 28),
            const SocialButtons(),
          ],
          const SizedBox(height: 26),
          Center(
            child: Text.rich(
              TextSpan(
                style: AppText.inter(fontSize: 14, color: AppColors.textMuted),
                children: [
                  const TextSpan(text: 'New to Utopia Health?  '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(
                        'Register',
                        style: AppText.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
