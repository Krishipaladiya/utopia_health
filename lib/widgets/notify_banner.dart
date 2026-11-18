import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/app_navigator.dart';

/// Icon and colours for each kind of alert.
(IconData, Color, Color) notifyStyle(String kind) => switch (kind) {
      'turn' => (Icons.campaign_rounded, const Color(0xFFFF7A00), const Color(0xFFFFF1E2)),
      'checkIn' => (Icons.how_to_reg_rounded, AppColors.primaryDark, AppColors.mint),
      'payment' => (Icons.currency_rupee_rounded, AppColors.success, AppColors.successSoft),
      'appointment' => (Icons.event_available_rounded, AppColors.info, AppColors.chipBlue),
      'prescription' || 'medicine' => (Icons.medication_rounded, const Color(0xFF7C4DFF), const Color(0xFFEDE7FF)),
      'lab' => (Icons.biotech_rounded, const Color(0xFF00838F), const Color(0xFFDFF6F7)),
      _ => (Icons.notifications_active_rounded, AppColors.primaryDark, AppColors.mint),
    };

OverlayEntry? _current;

/// Food-delivery style alert: drops in from the top with a bounce, the icon
/// pops and wiggles, a bar counts down, swipe up to dismiss, tap to open.
void showNotifyBanner({
  required String title,
  required String body,
  required String kind,
  VoidCallback? onTap,
}) {
  final overlay = appNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _current?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Banner(
      title: title,
      body: body,
      kind: kind,
      onTap: onTap,
      onDone: () {
        if (_current == entry) _current = null;
        entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _Banner extends StatefulWidget {
  const _Banner({
    required this.title,
    required this.body,
    required this.kind,
    required this.onDone,
    this.onTap,
  });

  final String title;
  final String body;
  final String kind;
  final VoidCallback onDone;
  final VoidCallback? onTap;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with TickerProviderStateMixin {
  static const _visible = Duration(seconds: 5);

  late final _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final _icon = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _timer = AnimationController(vsync: this, duration: _visible);
  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _slide.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _icon.forward();
    });
    _timer.forward().whenComplete(_close);
  }

  @override
  void dispose() {
    _slide.dispose();
    _icon.dispose();
    _timer.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _slide.animateBack(0, duration: const Duration(milliseconds: 280), curve: Curves.easeInCubic);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = notifyStyle(widget.kind);
    final top = MediaQuery.paddingOf(context).top + 8;

    final drop = CurvedAnimation(parent: _slide, curve: Curves.elasticOut, reverseCurve: Curves.easeIn);
    final pop = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
    ]).animate(_icon);
    final wiggle = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.06), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.06), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.0), weight: 25),
    ]).animate(_icon);

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -140 * (1 - drop.value) + _drag),
          child: Opacity(opacity: _slide.value.clamp(0.0, 1.0), child: child),
        ),
        child: GestureDetector(
          onTap: () {
            widget.onTap?.call();
            _close();
          },
          onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-120.0, 12.0)),
          onVerticalDragEnd: (d) {
            if (_drag < -30 || d.velocity.pixelsPerSecond.dy < -300) {
              _close();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Material(
            color: Colors.white,
            elevation: 10,
            shadowColor: const Color(0x401B2740),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _icon,
                        builder: (context, child) => Transform.rotate(
                          angle: wiggle.value * 3.14,
                          child: Transform.scale(scale: pop.value, child: child),
                        ),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 25),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: color),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) => LinearProgressIndicator(
                    value: 1 - _timer.value,
                    minHeight: 3,
                    backgroundColor: bg,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bell with a bouncing badge for the unread count.
class BellBadge extends StatelessWidget {
  const BellBadge({super.key, required this.count, required this.onTap, this.color});

  final int count;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, color: color ?? AppColors.textPrimary),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(count),
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: AppText.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps a timer alive for screens that refresh live numbers (e.g. waiting time).
class Ticker {
  Ticker(this.every, this.onTick) : _t = Timer.periodic(every, (_) => onTick());

  final Duration every;
  final VoidCallback onTick;
  final Timer _t;

  void cancel() => _t.cancel();
}
