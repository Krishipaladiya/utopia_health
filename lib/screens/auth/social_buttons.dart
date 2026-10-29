import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/social_sign_in.dart';
import 'auth_flow.dart';

/// "or continue with" Google / Apple. For doctors our team already onboarded.
class SocialButtons extends StatefulWidget {
  const SocialButtons({super.key});

  @override
  State<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends State<SocialButtons> {
  bool _busy = false;

  Future<void> _run(String provider, Future<String?> Function() getToken) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final token = await getToken();
      if (token == null) return; // cancelled
      await auth.socialLogin(provider, token);
      if (mounted) enterApp(context);
    } on ApiException catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = SocialSignIn.instance;

    Widget button(String label, IconData icon, VoidCallback onTap) {
      return Expanded(
        child: SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : onTap,
            icon: Icon(icon, size: 22, color: AppColors.textPrimary),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFDDE3F5)),
              shape: const StadiumBorder(),
              textStyle: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFDDE3F5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFDDE3F5))),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            button('Google', Icons.g_mobiledata_rounded, () => _run('google', social.googleIdToken)),
            if (social.appleAvailable) ...[
              const SizedBox(width: 12),
              button('Apple', Icons.apple, () => _run('apple', social.appleIdToken)),
            ],
          ],
        ),
      ],
    );
  }
}
