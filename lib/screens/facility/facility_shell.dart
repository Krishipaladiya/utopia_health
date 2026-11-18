import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../models/models.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/session.dart';
import '../../widgets/common.dart';
import '../../widgets/notify_banner.dart';
import '../../widgets/record_media.dart';
import '../auth/login_screen.dart';
import '../inbox_screen.dart';
import '../auth/delete_account.dart';
import '../../widgets/legal.dart';

/// App for partner clinics (prescriptions sent by the doctor) and
/// laboratories (test orders, sample status, report upload).
class FacilityShell extends StatefulWidget {
  const FacilityShell({super.key});

  @override
  State<FacilityShell> createState() => _FacilityShellState();
}

class _FacilityShellState extends State<FacilityShell> {
  String _filter = 'Open';

  @override
  void initState() {
    super.initState();
    inbox.onNew = (n) => showNotifyBanner(
      title: n.title,
      body: n.body,
      kind: n.type,
      onTap: _openInbox,
    );
    NotificationService.instance.init().then(
      (_) => NotificationService.instance.requestPermission(),
    );
    auth.startSession();
  }

  @override
  void dispose() {
    inbox.onNew = null;
    super.dispose();
  }

  void _openInbox() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const InboxScreen()));

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await auth.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lab = session.isLab;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.facilityName,
              style: AppText.poppins(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              '${lab ? 'Laboratory' : 'Partner clinic'} • ${session.memberName}',
              style: AppText.inter(
                fontSize: 12,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: inbox,
            builder: (context, _) =>
                BellBadge(count: inbox.unread, onTap: _openInbox),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'delete' => confirmDeleteAccount(context),
              'privacy' || 'terms' => openLegal(v),
              _ => _logout(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'out', child: Text('Log out')),
              PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
              PopupMenuItem(value: 'terms', child: Text('Terms of Use')),
              PopupMenuItem(value: 'delete', child: Text('Delete account')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: facilityStore,
        builder: (context, _) {
          final open = lab
              ? const ['Ordered', 'SampleCollected']
              : const ['Sent', 'Ready'];
          final rx = facilityStore.prescriptions
              .where((r) => (_filter == 'Open') == open.contains(r.status))
              .toList();
          final orders = facilityStore.labOrders
              .where((o) => (_filter == 'Open') == open.contains(o.status))
              .toList();
          final count = lab ? orders.length : rx.length;

          return RefreshIndicator(
            onRefresh: facilityStore.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (facilityStore.error != null)
                  ErrorBanner(
                    message: facilityStore.error!,
                    onRetry: facilityStore.refresh,
                  ),
                Row(
                  children: [
                    for (final f in const ['Open', 'Done'])
                      FilterPill(
                        label: f,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SectionLabel(
                  lab ? 'Test orders' : 'Prescriptions',
                  trailing: '$count',
                ),
                if (!facilityStore.loaded)
                  const LinearProgressIndicator(minHeight: 2),
                if (facilityStore.loaded && count == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Column(
                      children: [
                        Icon(
                          lab
                              ? Icons.biotech_outlined
                              : Icons.local_pharmacy_outlined,
                          size: 40,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filter == 'Open'
                              ? 'Nothing waiting. New ones appear here live.'
                              : 'Nothing completed yet.',
                          style: AppText.inter(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (lab)
                  for (final o in orders) _LabCard(order: o)
                else
                  for (final r in rx) _RxCard(rx: r),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx});

  final FacilityRx rx;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (rx.status) {
      'Ready' => ('Ready to collect', AppColors.info, AppColors.chipBlue),
      'Dispensed' => ('Given', AppColors.success, AppColors.successSoft),
      _ => ('New', AppColors.warning, AppColors.warningSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarCircle(name: rx.patientName, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rx.patientName,
                        style: AppText.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rx.patientAge}y / ${rx.patientGender == 'Female' ? 'F' : 'M'} • ${rx.patientPhone} • ${relativeTime(rx.date)}',
                        style: AppText.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AppChip(
                  label: label,
                  color: bg,
                  textColor: color,
                  fontSize: 11,
                  bold: true,
                ),
              ],
            ),
            const Divider(height: 22),
            for (final i in rx.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: i.name,
                              style: AppText.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: '\n${i.dose} • ${i.timing} • ${i.course}',
                              style: AppText.inter(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (rx.notes.isNotEmpty)
              Text(
                'Note: ${rx.notes}',
                style: AppText.inter(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            const SizedBox(height: 8),
            if (rx.status != 'Dispensed')
              Row(
                children: [
                  if (rx.status == 'Sent')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => runAction(
                          context,
                          () => facilityStore.setRxStatus(rx, 'Ready'),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: const Text('Mark ready'),
                      ),
                    ),
                  if (rx.status == 'Sent') const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => runAction(
                        context,
                        () => facilityStore.setRxStatus(rx, 'Dispensed'),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Given'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard({required this.order});

  final LabTest order;

  Future<void> _upload(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF or document'),
              onTap: () => Navigator.pop(context, 'document'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('From gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await pickUpload(source);
    if (file == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (await runAction(
      context,
      () => facilityStore.uploadReport(order, file),
    )) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report sent to the doctor and the patient'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (order.status) {
      'ReportReady' => (AppColors.success, AppColors.successSoft),
      'SampleCollected' => (AppColors.info, AppColors.chipBlue),
      _ => (AppColors.warning, AppColors.warningSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarCircle(name: order.memberName, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.memberName,
                        style: AppText.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${order.patientAge}y • ${order.patientPhone} • ${relativeTime(order.date)}',
                        style: AppText.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AppChip(
                  label: order.statusLabel,
                  color: bg,
                  textColor: color,
                  fontSize: 11,
                  bold: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.chipBlueSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.biotech_rounded,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.tests,
                      style: AppText.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Note: ${order.notes}',
                style: AppText.inter(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (order.status == 'Ordered')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => runAction(
                        context,
                        () => facilityStore.setLabStatus(
                          order,
                          'SampleCollected',
                        ),
                      ),
                      icon: const Icon(Icons.bloodtype_outlined, size: 18),
                      label: const Text('Sample taken'),
                    ),
                  ),
                if (order.status == 'Ordered') const SizedBox(width: 8),
                Expanded(
                  child: order.hasReport
                      ? OutlinedButton.icon(
                          onPressed: () => openReport(context, order),
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: const Text('View report'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _upload(context),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Upload report'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Downloads a lab report and opens it.
Future<void> openReport(BuildContext context, LabTest order) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await openRemoteFile(
      context,
      '/api/lab-orders/${order.id}/report',
      'report-${order.id}.pdf',
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
  }
}
