import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/clinic_store.dart';
import '../firebase_options.dart';
import '../screens/notifications_screen.dart';
import 'api_client.dart';
import 'app_navigator.dart';
import 'notification_service.dart';

/// Firebase Cloud Messaging: alerts that reach the phone while the app is
/// closed. If the Firebase config files are not added yet, this quietly stays
/// off and the app keeps using live in-app alerts only.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _started = false;
  String? _token;

  /// true once Firebase is set up, permission is given and the phone is registered.
  final ValueNotifier<bool> active = ValueNotifier(false);

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start() async {
    if (!_supported || _started) return;

    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options == null) {
        debugPrint('Push is off: fill lib/firebase_options.dart');
        return;
      }
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    } catch (e) {
      debugPrint('Push is off (Firebase config files not added yet): $e');
      return;
    }
    _started = true;

    final fm = FirebaseMessaging.instance;
    try {
      final settings = await fm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push is off: notification permission denied');
        return;
      }

      // Emits the phone's push token now and again whenever it changes.
      fm.onRegistered.listen(_register);
      // App open: the live connection already updates the screen; just stay in sync.
      FirebaseMessaging.onMessage.listen((_) => notifications.load());
      FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotifications());

      // Tapping an alert while the app was fully closed.
      final launch = await fm.getInitialMessage();
      if (launch != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openNotifications());
      }

      NotificationService.instance.remotePushActive = true;
      active.value = true;

      await fm.register();
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    if (!api.hasSession) return;
    try {
      await api.post('/api/devices', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } on ApiException catch (e) {
      debugPrint('Could not register push token: ${e.code}');
    }
  }

  void _openNotifications() {
    notifications.load();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  /// Logout: tell the server to stop sending to this phone.
  Future<void> stop() async {
    if (!_started) return;
    final token = _token;
    NotificationService.instance.remotePushActive = false;
    active.value = false;
    if (token != null && api.hasSession) {
      try {
        await api.post('/api/devices/remove', {'token': token});
      } on ApiException {
        // best effort
      }
    }
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
    _token = null;
    _started = false;
  }
}
