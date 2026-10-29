import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/notification_service.dart';
import 'finance_screen.dart';
import 'notifications_screen.dart';
import 'patients_screen.dart';
import 'queue_screen.dart';
import 'rx_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Fades the tab in when the doctor switches tabs.
  late final _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    notifications.onNew = _showBanner;
    NotificationService.instance.init().then((_) {
      if (mounted && !NotificationService.instance.permissionGranted.value) {
        NotificationService.instance.requestPermission();
      }
    });
    auth.startSession();
  }

  @override
  void dispose() {
    notifications.onNew = null;
    _tabFade.dispose();
    RealtimeService.instance.stop();
    super.dispose();
  }

  /// In-app banner for events that arrive while the app is open.
  void _showBanner(AppNotification n) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 5),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              n.title,
              style: AppText.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              n.body,
              style: AppText.inter(fontSize: 12.5, color: Colors.white70),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.aqua,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: _tabFade, curve: Curves.easeOutCubic),
                ),
            child: IndexedStack(
              index: _index,
              children: const [
                QueueScreen(),
                RxScreen(),
                PatientsScreen(),
                FinanceScreen(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (value == _index) return;
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _index = value);
          _tabFade.forward(from: 0);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services_rounded),
            label: 'Rx',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finance',
          ),
        ],
      ),
    );
  }
}
