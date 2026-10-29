import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api_client.dart';

/// Google and Apple sign-in. They only work after the client ids are set up
/// (see backend/SOCIAL_LOGIN.md). Without them the buttons show a clear message.
///
/// Build-time settings:
///   --dart-define=GOOGLE_CLIENT_ID=...         (iOS and web client id)
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=...  (the web client id, needed on Android)
class SocialSignIn {
  SocialSignIn._();

  static final SocialSignIn instance = SocialSignIn._();

  static const _clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '40549200434-frs420g5jkcv6fjsckojbp3efe01mg9e.apps.googleusercontent.com',
  );
  static const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  bool _googleReady = false;

  /// Apple's button is shown on iPhones (Apple requires it next to other social logins).
  bool get appleAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// An ID token from Google, or null if the person cancelled.
  /// Throws [ApiException] with code `social_not_configured` if client ids are missing.
  Future<String?> googleIdToken() async {
    if (_clientId.isEmpty && _serverClientId.isEmpty) {
      throw ApiException(501, 'social_not_configured');
    }
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          clientId: _clientId.isEmpty ? null : _clientId,
          serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
        );
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw ApiException(401, 'invalid_social_token');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google sign-in failed: $e');
      throw ApiException(401, 'invalid_social_token');
    }
  }

  /// An identity token from Apple, or null if the person cancelled.
  Future<String?> appleIdToken() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      return credential.identityToken;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('Apple sign-in failed: $e');
      throw ApiException(401, 'invalid_social_token');
    }
  }
}
