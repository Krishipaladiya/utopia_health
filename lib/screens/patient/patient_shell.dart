import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../data/reminders.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../../widgets/notify_banner.dart';
import '../content/content_views.dart';
import '../inbox_screen.dart';
import 'explore_screen.dart';
import 'family_screen.dart';
import 'records_screen.dart';
import 'scan_screen.dart';

/// The patient app: live token, medicine reminders, nearby clinics and
/// health camps, records for every family member on the same number.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);

  @override
  void initState() {
    super.initState();
    inbox.onNew = (n) => showNotifyBanner(title: n.title, body: n.body, kind: n.type, onTap: _openInbox);
    NotificationService.instance.init().then((_) => NotificationService.instance.requestPermission());
    auth.startSession();
  }

  @override
  void dispose() {
    inbox.onNew = null;
    _fade.dispose();
    super.dispose();
  }

  void _openInbox() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InboxScreen()));

  void _go(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fade,
          child: IndexedStack(
            index: _index,
            children: [
              _HomeTab(onExplore: () => _go(1), onRecords: () => _go(2), onFamily: () => _go(3), onInbox: _openInbox),
              const ExploreScreen(),
              const RecordsScreen(),
              const FamilyScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.folder_shared_outlined), selectedIcon: Icon(Icons.folder_shared_rounded), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom_rounded), label: 'Family'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onExplore, required this.onRecords, required this.onFamily, required this.onInbox});

  final VoidCallback onExplore;
  final VoidCallback onRecords;
  final VoidCallback onFamily;
  final VoidCallback onInbox;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Camp> _camps = [];
  List<BlogPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final pos = await currentPosition();
    try {
      final results = await Future.wait([
        api.get('/api/explore/camps', query: {'lat': pos?.latitude.toString(), 'lng': pos?.longitude.toString()}),
        api.get('/api/explore/posts'),
      ]);
      if (!mounted) return;
      setState(() {
        _camps = (results[0] as List).map((e) => Camp.fromJson(e as Map<String, dynamic>)).toList();
        _posts = (results[1] as List).map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on ApiException {
      // feed is optional
    }
  }

  Future<void> _refresh() async {
    await Future.wait([patientStore.loadAll(), _loadFeed()]);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([patientStore, inbox, medicineReminders]),
      builder: (context, _) {
        final self = patientStore.members.where((m) => m.relationship == 'Self').firstOrNull ?? patientStore.members.firstOrNull;
        final upcoming = patientStore.appointments
            .where((a) => a.start.isAfter(DateTime.now()) && (a.status == 'Booked' || a.status == 'Requested'))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: const Image(image: AssetImage('assets/images/app_icon_light.png'), width: 40, height: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting, style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
                        Text(
                          self?.name ?? 'Welcome',
                          style: AppText.poppins(fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  BellBadge(count: inbox.unread, onTap: widget.onInbox),
                ],
              ),
              const SizedBox(height: 14),
              for (final t in patientStore.tokens.where((t) => t.status != 'Completed' && t.status != 'Missed'))
                _TokenCard(token: t),
              Row(
                children: [
                  _Action(icon: Icons.qr_code_scanner_rounded, label: 'Scan &\nget token', color: const Color(0xFF00897B), onTap: () => openScan(context)),
                  _Action(icon: Icons.event_available_rounded, label: 'Book\nvisit', color: const Color(0xFF3949AB), onTap: widget.onExplore),
                  _Action(icon: Icons.description_rounded, label: 'My\nrecords', color: const Color(0xFF7B1FA2), onTap: widget.onRecords),
                  _Action(icon: Icons.group_add_rounded, label: 'Family\n(${patientStore.members.length})', color: const Color(0xFFEF6C00), onTap: widget.onFamily),
                ],
              ),
              const SizedBox(height: 18),
              SectionLabel("Today's medicines", trailing: medicineReminders.enabled ? 'Reminders on' : 'Reminders off'),
              if (medicineReminders.today.isEmpty)
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.medication_outlined, color: AppColors.textFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No medicines today. When a doctor prescribes, reminders appear here.',
                          style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final d in medicineReminders.today) _DoseCard(dose: d),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 14),
                const SectionLabel('Upcoming visits'),
                for (final a in upcoming.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.event_rounded, color: AppColors.primaryDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${a.memberName} • ${a.clinicName}', style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                                Text('${dayDate(a.start)} • ${clock(a.start)}', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          AppChip(
                            label: a.status == 'Requested' ? 'Waiting' : 'Confirmed',
                            color: a.status == 'Requested' ? AppColors.warningSoft : AppColors.successSoft,
                            textColor: a.status == 'Requested' ? AppColors.warning : AppColors.success,
                            fontSize: 11,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (_camps.isNotEmpty) ...[
                const SizedBox(height: 14),
                const SectionLabel('Health camps near you'),
                SizedBox(
                  height: 178,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _camps.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => CampCard(camp: _camps[i], width: 270),
                  ),
                ),
              ],
              if (_posts.isNotEmpty) ...[
                const SizedBox(height: 14),
                const SectionLabel('From doctors'),
                SizedBox(
                  height: 236,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _posts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => BlogCard(post: _posts[i], width: 250),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Live token: number, how many ahead, a ring that fills as the turn nears.
class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.token});

  final MyToken token;

  @override
  Widget build(BuildContext context) {
    final inRoom = token.status == 'InConsult';
    final progress = inRoom ? 1.0 : 1 / (token.ahead + 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: inRoom ? const [Color(0xFFFF7A00), Color(0xFFFFA040)] : const [Color(0xFF00695C), Color(0xFF26A69A)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x3300695C), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(value: v, strokeWidth: 6, color: Colors.white, backgroundColor: Colors.white24),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('TOKEN', style: AppText.inter(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w700)),
                          Text('#${token.number}', style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inRoom ? "It's your turn!" : (token.ahead == 0 ? "You're next" : '${token.ahead} ahead of you'),
                    style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    inRoom ? 'Please go in now' : 'About ${token.waitMinutes} min wait',
                    style: AppText.inter(fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${token.memberName} • ${token.clinicName}${token.nowServing == null ? '' : ' • Now: #${token.nowServing}'}',
                    maxLines: 2,
                    style: AppText.inter(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: AppText.inter(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.dose});

  final DoseTime dose;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final past = now.hour * 60 + now.minute > dose.hour * 60 + dose.minute;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: past ? AppColors.chipBlue : AppColors.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(dose.label, style: AppText.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                  Text(dose.timeText, style: AppText.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in dose.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(l, style: AppText.inter(fontSize: 13, height: 1.35)),
                    ),
                ],
              ),
            ),
            Icon(past ? Icons.check_circle_outline_rounded : Icons.alarm_rounded, color: past ? AppColors.textFaint : AppColors.primaryDark),
          ],
        ),
      ),
    );
  }
}
