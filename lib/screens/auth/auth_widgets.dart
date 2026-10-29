import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../widgets/wave_background.dart';

/// Page frame shared by login and register: brand logo, content, wave footer.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBack = false,
  });

  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 150,
            child: WaveBackground(start: 0.34),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: showBack
                        ? IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Image(
      image: AssetImage('assets/images/logo_horizontal.png'),
      width: 210,
      alignment: Alignment.centerLeft,
    );
  }
}

class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.poppins(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppText.inter(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        text,
        style: AppText.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration({
  required String hint,
  Widget? prefix,
  IconData? icon,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.inter(fontSize: 15, color: AppColors.textFaint),
    filled: true,
    fillColor: Colors.white,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: prefix ??
        (icon == null
            ? null
            : Icon(icon, size: 20, color: AppColors.textMuted)),
    enabledBorder: border(const Color(0xFFDDE3F5)),
    focusedBorder: border(AppColors.primaryDark, 1.6),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.6),
  );
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: authInputDecoration(hint: hint, icon: icon),
    );
  }
}

class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
      decoration: authInputDecoration(
        hint: '98250 14820',
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+91',
                style: AppText.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1.5, height: 22, color: const Color(0xFFDDE3F5)),
            ],
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          disabledBackgroundColor: const Color(0xFFB9D5CF),
          disabledForegroundColor: Colors.white,
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

String formatPhone(String digits) {
  if (digits.length != 10) return '+91 $digits';
  return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
}

/// OTP entry: six boxes that verify by themselves once the last digit is typed.
/// [onSubmit] returns an error message to show, or null on success.
/// [devCode] is only set by a development server so testers can log in.
class OtpPanel extends StatefulWidget {
  const OtpPanel({
    super.key,
    required this.sentTo,
    required this.channel,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeNumber,
    this.devCode,
  });

  /// Where the code went, e.g. +91 98250 14820 or doctor@example.com.
  final String sentTo;

  /// How it was sent: SMS or email.
  final String channel;
  final Future<String?> Function(String code) onSubmit;
  final Future<String?> Function() onResend;
  final VoidCallback onChangeNumber;
  final String? devCode;

  @override
  State<OtpPanel> createState() => _OtpPanelState();
}

class _OtpPanelState extends State<OtpPanel> {
  static const _length = 6;
  static const _resendSeconds = 30;

  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _nodes = List.generate(_length, (_) => FocusNode());
  Timer? _timer;
  int _left = _resendSeconds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes.first.requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) t.cancel();
      if (mounted) setState(() => _left = _left - 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _complete => _code.length == _length;

  void _onDigit(int i, String value) {
    if (value.isNotEmpty && i < _length - 1) {
      _nodes[i + 1].requestFocus();
    }
    setState(() => _error = null);
    if (_complete && !_busy) _submit();
  }

  KeyEventResult _onKey(int i, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[i].text.isEmpty &&
        i > 0) {
      _controllers[i - 1].clear();
      _nodes[i - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error != null) {
      // Wrong code: start again from the first box.
      for (final c in _controllers) {
        c.clear();
      }
      _nodes.first.requestFocus();
    }
  }

  Future<void> _resend() async {
    final error = await widget.onResend();
    if (!mounted) return;
    if (error == null) _startTimer();
    setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppText.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                  children: [
                    TextSpan(text: 'Code sent by ${widget.channel} to '),
                    TextSpan(
                      text: widget.sentTo,
                      style: AppText.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onChangeNumber,
              child: Text(
                'Change',
                style: AppText.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _length; i++)
              SizedBox(
                width: 46,
                height: 56,
                child: Focus(
                  onKeyEvent: (_, event) => _onKey(i, event),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => _onDigit(i, v),
                    style: AppText.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: authInputDecoration(hint: '').copyWith(
                      contentPadding: EdgeInsets.zero,
                      fillColor: _controllers[i].text.isEmpty
                          ? Colors.white
                          : AppColors.mintSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppText.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              _left > 0
                  ? 'Resend OTP in 0:${_left.toString().padLeft(2, '0')}'
                  : "Didn't get it?",
              style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
            ),
            if (_left <= 0)
              TextButton(
                onPressed: _resend,
                child: Text(
                  'Resend OTP',
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_busy)
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 10),
              Text(
                'Verifying...',
                style: AppText.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        if (widget.devCode != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Development server: any 6 digits work',
              style: AppText.inter(fontSize: 12, color: AppColors.textFaint),
            ),
          ),
        ],
      ],
    );
  }
}
