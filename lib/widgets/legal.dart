import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';

/// Opens /privacy or /terms on the server.
Future<void> openLegal(String page) => launchUrl(
      Uri.parse('${ApiConfig.baseUrl}/$page'),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
      webOnlyWindowName: '_blank',
    );

/// "By continuing you agree to the Terms of Use and Privacy Policy." with links.
class LegalAgreementText extends StatelessWidget {
  const LegalAgreementText({super.key, this.prefix = 'By continuing you agree to the '});

  final String prefix;

  @override
  Widget build(BuildContext context) {
    final base = AppText.inter(fontSize: 12, color: AppColors.textMuted, height: 1.4);
    final link = AppText.inter(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w700, height: 1.4);
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: prefix),
        TextSpan(text: 'Terms of Use', style: link, recognizer: TapGestureRecognizer()..onTap = () => openLegal('terms')),
        const TextSpan(text: ' and '),
        TextSpan(text: 'Privacy Policy', style: link, recognizer: TapGestureRecognizer()..onTap = () => openLegal('privacy')),
        const TextSpan(text: '.'),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// Two small links for settings screens.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(onPressed: () => openLegal('privacy'), child: const Text('Privacy Policy')),
        Text('·', style: AppText.inter(color: AppColors.textFaint)),
        TextButton(onPressed: () => openLegal('terms'), child: const Text('Terms of Use')),
      ],
    );
  }
}
