import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System notifications (status bar / lock screen) on Android and iOS.
/// Web and desktop only get the in-app feed.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Set by the push service. When Firebase delivers alerts to the phone, the
  /// local copy is skipped so one event never shows twice.
  bool remotePushActive = false;

  /// True once the user has allowed notifications.
  final ValueNotifier<bool> permissionGranted = ValueNotifier(false);

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
      await _createChannel();
      await _refreshPermission();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Channel used by local alerts and by Firebase alerts (Android 8+).
  Future<void> _createChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'clinic_alerts',
        'Clinic alerts',
        description: 'Queue check-ins, appointments, payments and prescriptions',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _refreshPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      permissionGranted.value =
          await android.areNotificationsEnabled() ?? false;
    }
  }

  /// Asks the OS for permission. Returns whether it was granted.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    if (!_ready) await init();
    bool granted = false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        granted = await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        granted = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('Notification permission failed: $e');
    }
    permissionGranted.value = granted;
    return granted;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (remotePushActive) return;
    if (!_supported || !_ready || !permissionGranted.value) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'clinic_alerts',
            'Clinic alerts',
            channelDescription:
                'Queue check-ins, appointments, payments and prescriptions',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notification show failed: $e');
    }
  }
}
