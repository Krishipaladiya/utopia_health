import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';
import 'social_buttons.dart';

enum _Step { phone, phoneCode, email, emailCode, done }

/// Doctor registration in two quick checks: mobile number, then email.
/// Each code is sent and verified by itself. After that our team contacts the
/// doctor and sets everything up, so nothing else is typed here.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _phone = TextEditingController();
  final _email = TextEditingController();

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;
  String? _devCode;
  String? _phoneProof;
  Timer? _emailDebounce;

  bool get _validPhone => _phone.text.length == 10;
  bool get _validEmail => _emailPattern.hasMatch(_email.text.trim());

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  // ---- step 1: mobile -----------------------------------------------------

  Future<String?> _sendPhoneCode() async {
    try {
      _devCode = await auth.sendOtp(_phone.text);
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  Future<void> _startPhone() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _sendPhoneCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _step = _Step.phoneCode;
    });
  }

  Future<String?> _verifyPhone(String code) async {
    try {
      _phoneProof = await auth.verifyContact('phone', _phone.text, code);
      if (mounted) setState(() => _step = _Step.email);
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  // ---- step 2: email ------------------------------------------------------

  Future<String?> _sendEmailCode() async {
    try {
      _devCode = await auth.sendEmailOtp(_email.text.trim());
      return null;
    } on ApiException catch (e) {
      return e.friendly;
    }
  }

  Future<void> _startEmail() async {
    if (_busy || !_validEmail) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _sendEmailCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _step = _Step.emailCode;
    });
  }

  /// Sends the email code by itself shortly after a valid address is typed.
  void _onEmailChanged(String _) {
    setState(() => _error = null);
    _emailDebounce?.cancel();
    if (_validEmail) {
      _emailDebounce = Timer(const Duration(milliseconds: 900), _startEmail);
    }
  }

  Future<String?> _verifyEmail(String code) async {
    try {
      final emailProof = await auth.verifyContact('email', _email.text.trim(), code);
      await auth.requestRegistration(phoneProof: _phoneProof!, emailProof: emailProof);
      if (mounted) setState(() => _step = _Step.done);
      return null;
    } on ApiException catch (e) {
      if (e.code == 'verification_expired' || e.code == 'already_registered') {
        // Phone proof is no longer usable (or already registered): start over.
        if (mounted) {
          setState(() {
            _step = _Step.phone;
            _phoneProof = null;
          });
        }
      }
      return e.friendly;
    }
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final done = _step == _Step.done;

    return AuthScaffold(
      showBack: !done,
      child: done ? _doneView() : _formView(),
    );
  }

  Widget _formView() {
    final onEmail = _step == _Step.email || _step == _Step.emailCode;
    final title = switch (_step) {
      _Step.phone => 'Create your account',
      _Step.phoneCode => 'Verify your mobile',
      _Step.email => 'Now your email',
      _ => 'Verify your email',
    };
    final subtitle = switch (_step) {
      _Step.phone => 'Just your mobile number and email. Our team sets up the rest for you.',
      _Step.phoneCode => 'Enter the 6-digit code. It is checked automatically.',
      _Step.email => 'We will email you a 6-digit code.',
      _ => 'Enter the 6-digit code. It is checked automatically.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Progress(step: onEmail ? 2 : 1),
        const SizedBox(height: 20),
        AuthHeading(title: title, subtitle: subtitle),
        const SizedBox(height: 22),
        if (_step == _Step.phone) ...[
          const FieldLabel('Mobile number'),
          PhoneField(
            controller: _phone,
            onChanged: (v) {
              setState(() => _error = null);
              if (v.length == 10) _startPhone();
            },
          ),
          const SizedBox(height: 10),
          _status(
            sending: _busy,
            sendingText: 'Sending code...',
            hint: 'The code is sent as soon as you enter all 10 digits.',
            retry: _validPhone ? _startPhone : null,
          ),
          const SizedBox(height: 28),
          const SocialButtons(caption: 'or start now with'),
        ],
        if (_step == _Step.phoneCode)
          OtpPanel(
            sentTo: formatPhone(_phone.text),
            channel: 'SMS',
            devCode: _devCode,
            onChangeNumber: () => setState(() => _step = _Step.phone),
            onResend: _sendPhoneCode,
            onSubmit: _verifyPhone,
          ),
        if (onEmail) ...[
          if (_phoneProof != null) _VerifiedChip(text: '${formatPhone(_phone.text)} verified'),
          const SizedBox(height: 4),
        ],
        if (_step == _Step.email) ...[
          const FieldLabel('Email address'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onChanged: _onEmailChanged,
            onSubmitted: (_) => _startEmail(),
            style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: authInputDecoration(
              hint: 'doctor@example.com',
              icon: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 10),
          _status(
            sending: _busy,
            sendingText: 'Sending code...',
            hint: 'The code is sent as soon as the address looks complete.',
            retry: _validEmail ? _startEmail : null,
          ),
        ],
        if (_step == _Step.emailCode)
          OtpPanel(
            sentTo: _email.text.trim(),
            channel: 'email',
            devCode: _devCode,
            onChangeNumber: () => setState(() => _step = _Step.email),
            onResend: _sendEmailCode,
            onSubmit: _verifyEmail,
          ),
      ],
    );
  }

  Widget _status({
    required bool sending,
    required String sendingText,
    required String hint,
    required VoidCallback? retry,
  }) {
    if (sending) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 10),
          Text(
            sendingText,
            style: AppText.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return Row(
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
          if (retry != null) TextButton(onPressed: retry, child: const Text('Try again')),
        ],
      );
    }
    return Text(hint, style: AppText.inter(fontSize: 12, color: AppColors.textMuted));
  }

  Widget _doneView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 40, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 22),
        const AuthHeading(
          title: 'Thank you!',
          subtitle:
              'We have received your registration and sent a confirmation to your email.',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.mint),
          ),
          child: Column(
            children: [
              _doneRow(Icons.phone_outlined, formatPhone(_phone.text)),
              const Divider(height: 22),
              _doneRow(Icons.mail_outline_rounded, _email.text.trim()),
              const Divider(height: 22),
              _doneRow(
                Icons.support_agent_rounded,
                'Our team will contact you soon and set up your clinic. You do not need to enter anything else.',
                strong: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: 'Back to login',
          icon: Icons.login_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _doneRow(IconData icon, String text, {bool strong = true}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppText.inter(
              fontSize: 14,
              height: 1.4,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    Widget bar(bool on) => Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: on ? AppColors.primaryDark : AppColors.chipBlue,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        );

    return Row(
      children: [
        bar(step >= 1),
        const SizedBox(width: 6),
        bar(step >= 2),
        const SizedBox(width: 12),
        Text(
          'Step $step of 2',
          style: AppText.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppText.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
