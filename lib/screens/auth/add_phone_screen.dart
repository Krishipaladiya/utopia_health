import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/doctor_store.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'auth_flow.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

/// After the first Google / Apple sign-in: the doctor adds their mobile
/// number once (checked with an SMS code) and can rename the clinic.
class AddPhoneScreen extends StatefulWidget {
  const AddPhoneScreen({super.key});

  @override
  State<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends State<AddPhoneScreen> {
  final _phone = TextEditingController();
  late final _clinic = TextEditingController(text: doctorProfile.clinic);
  bool _otpStep = false;
  bool _sending = false;
  String? _error;
  String? _devCode;

  bool get _validPhone => _phone.text.length == 10;

  @override
  void dispose() {
    _phone.dispose();
    _clinic.dispose();
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

  Future<String?> _verify(String code) async {
    try {
      await auth.addPhone(_phone.text, code, clinicName: _clinic.text);
      if (mounted) enterApp(context, newlyRegistered: true);
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  Future<void> _useAnotherAccount() async {
    final navigator = Navigator.of(context);
    await auth.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthHeading(
            title: _otpStep ? 'Verify your number' : 'Add your mobile',
            subtitle: _otpStep
                ? 'Enter the 6-digit code. It is checked automatically.'
                : 'Welcome, ${doctorProfile.name}. Add your mobile number once to finish.',
          ),
          const SizedBox(height: 24),
          if (!_otpStep) ...[
            const FieldLabel('Clinic name'),
            TextField(
              controller: _clinic,
              textCapitalization: TextCapitalization.words,
              style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: authInputDecoration(
                hint: 'Your clinic name',
                icon: Icons.local_hospital_outlined,
              ),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Mobile number'),
            PhoneField(
              controller: _phone,
              onChanged: (v) {
                setState(() => _error = null);
                if (v.length == 10) _sendOtp();
              },
            ),
            const SizedBox(height: 10),
            if (_sending)
              Text(
                'Sending code...',
                style: AppText.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
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
          const SizedBox(height: 26),
          Center(
            child: TextButton(
              onPressed: _useAnotherAccount,
              child: const Text('Use another account'),
            ),
          ),
        ],
      ),
    );
  }
}
