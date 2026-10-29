import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/social_sign_in.dart';
import 'add_phone_screen.dart';
import 'auth_flow.dart';

/// "Continue with Google / Apple". A new doctor gets an account at once.
/// [dividerFirst] puts the "or" line above the buttons (login), otherwise
/// below them (sign-up, where Google/Apple is the quickest way).
class SocialButtons extends StatefulWidget {
  const SocialButtons({
    super.key,
    this.caption = 'or',
    this.dividerFirst = true,
  });

  final String caption;
  final bool dividerFirst;

  @override
  State<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends State<SocialButtons> {
  String? _busy;

  Future<void> _run(String provider, Future<SocialToken?> Function() getToken) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = provider);
    try {
      final result = await getToken();
      if (result == null) return; // cancelled
      final needsPhone = await auth.socialLogin(provider, result.token, name: result.name);
      if (!mounted) return;
      if (needsPhone) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AddPhoneScreen()),
          (_) => false,
        );
      } else {
        enterApp(context);
      }
    } on ApiException catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = SocialSignIn.instance;

    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE3E8F2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.caption,
              style: AppText.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE3E8F2))),
        ],
      ),
    );

    final buttons = Column(
      children: [
        _ProviderButton(
          label: 'Continue with Google',
          leading: const _GoogleMark(size: 20),
          busy: _busy == 'google',
          enabled: _busy == null,
          background: Colors.white,
          foreground: AppColors.textPrimary,
          border: const Color(0xFFDADCE0),
          onTap: () => _run('google', social.googleIdToken),
        ),
        if (social.appleAvailable) ...[
          const SizedBox(height: 12),
          _ProviderButton(
            label: 'Continue with Apple',
            leading: const Icon(Icons.apple, size: 23, color: Colors.white),
            busy: _busy == 'apple',
            enabled: _busy == null,
            background: Colors.black,
            foreground: Colors.white,
            onTap: () => _run('apple', social.appleIdToken),
          ),
        ],
      ],
    );

    return Column(
      children: widget.dividerFirst ? [divider, buttons] : [buttons, divider],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.leading,
    required this.busy,
    required this.enabled,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
  });

  final String label;
  final Widget leading;
  final bool busy;
  final bool enabled;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: background,
        shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border!)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    )
                  : leading,
              const SizedBox(width: 12),
              Text(label, style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w600, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four-colour Google "G", drawn so no image file is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    const deg = math.pi / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, -230 * deg, -95 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, -325 * deg, -35 * deg, false, p(const Color(0xFF4285F4)));
    // The bar of the G.
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, size.height * 0.5 - stroke / 2, size.width * 0.5, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
