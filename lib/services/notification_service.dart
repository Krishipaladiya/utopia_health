import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  bool _tzReady = false;

  /// Daily alert at [hour]:[minute] (India time) until cancelled. Used for medicine reminders.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_supported) return;
    if (!_ready) await init();
    try {
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        _tzReady = true;
      }
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_reminders',
            'Medicine reminders',
            channelDescription: 'Time to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('Reminder schedule failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
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
