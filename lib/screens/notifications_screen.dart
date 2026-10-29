import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static IconData _icon(NotificationKind k) => switch (k) {
        NotificationKind.checkIn => Icons.how_to_reg_outlined,
        NotificationKind.payment => Icons.payments_outlined,
        NotificationKind.appointment => Icons.event_available_outlined,
        NotificationKind.prescription => Icons.chat_outlined,
      };

  static Color _tint(NotificationKind k) => switch (k) {
        NotificationKind.checkIn => AppColors.mint,
        NotificationKind.payment => AppColors.successSoft,
        NotificationKind.appointment => AppColors.chipBlue,
        NotificationKind.prescription => const Color(0xFFD9F5EE),
      };

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: notifications,
          builder: (context, _) {
            final items = notifications.items;
            return Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: AppText.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            notifications.unread == 0 ? null : notifications.markAllRead,
                        child: Text(
                          'Mark all read',
                          style: AppText.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const _PermissionCard(),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: AppColors.chipBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 32,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No notifications yet',
                                style: AppText.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Check-ins, payments and reminders show up here live.',
                                textAlign: TextAlign.center,
                                style: AppText.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final n in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SoftCard(
                            onTap: () => notifications.markRead(n),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _tint(n.kind),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _icon(n.kind),
                                    color: AppColors.primaryDark,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: AppText.poppins(
                                                fontSize: 14.5,
                                                fontWeight: n.read
                                                    ? FontWeight.w500
                                                    : FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (!n.read)
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primaryGreen,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        n.body,
                                        style: AppText.inter(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        ago(n.time),
                                        style: AppText.inter(
                                          fontSize: 11.5,
                                          color: AppColors.textFaint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Asks for OS notification permission (Android 13+ / iOS).
/// Hidden on web and once granted.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context) {
    final mobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!mobile) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: NotificationService.instance.permissionGranted,
      builder: (context, granted, _) {
        if (granted) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Turn on alerts to hear about check-ins and appointments even when the app is closed.',
                    style: AppText.inter(fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: NotificationService.instance.requestPermission,
                  child: const Text('Allow'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
