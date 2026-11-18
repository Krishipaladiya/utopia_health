import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/network_stores.dart';
import '../models/models.dart';
import '../widgets/notify_banner.dart';

/// Notifications for patients, partner clinics and labs.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    inbox.load();
  }

  @override
  void dispose() {
    inbox.markAllRead();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Notifications', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [TextButton(onPressed: inbox.markAllRead, child: const Text('Mark all read'))],
      ),
      body: ListenableBuilder(
        listenable: inbox,
        builder: (context, _) {
          if (inbox.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 46, color: AppColors.textFaint),
                  const SizedBox(height: 8),
                  Text('No notifications yet', style: AppText.inter(fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: inbox.load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: inbox.items.length,
              itemBuilder: (context, i) => _Tile(n: inbox.items[i], index: i),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.n, required this.index});

  final AppNotification n;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = notifyStyle(n.type);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index < 8 ? index * 45 : 0)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(24 * (1 - t), 0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.read ? Colors.white : const Color(0xFFF2FBF7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: n.read ? const Color(0xFFE6EAF3) : AppColors.mint),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(n.body, style: AppText.inter(fontSize: 13, color: AppColors.textMuted, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(relativeTime(n.time), style: AppText.inter(fontSize: 11.5, color: AppColors.textFaint)),
                ],
              ),
            ),
            if (!n.read)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
