import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/doctor_store.dart';
import '../widgets/common.dart';

/// Doctor defines availability, slot length and patients per slot.
/// [onboarding] = shown right after registration (Skip / Finish setup).
class SlotSetupScreen extends StatefulWidget {
  const SlotSetupScreen({super.key, this.onboarding = false, this.onDone});

  final bool onboarding;
  final VoidCallback? onDone;

  @override
  State<SlotSetupScreen> createState() => _SlotSetupScreenState();
}

class _SlotSetupScreenState extends State<SlotSetupScreen> {
  bool _saving = false;

  bool get onboarding => widget.onboarding;
  VoidCallback? get onDone => widget.onDone;

  @override
  void initState() {
    super.initState();
    // Show what the server has; ignore failures (defaults stay on screen).
    slotConfig.load().catchError((_) {});
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final ok = await runAction(context, slotConfig.save);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Slots saved')));
      _finish(context);
    }
  }

  void _finish(BuildContext context) {
    if (onDone != null) {
      onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
              child: Row(
                children: [
                  if (!onboarding)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          onboarding
                              ? 'Set your availability'
                              : 'Appointment slots',
                          style: AppText.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          onboarding
                              ? 'Step 2 of 2 • You can change this anytime'
                              : 'Days, timings and booking capacity',
                          style: AppText.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onboarding)
                    TextButton(
                      onPressed: () => _finish(context),
                      child: Text(
                        'Skip',
                        style: AppText.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: slotConfig,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: const [
                    _SlotSettingsCard(),
                    SizedBox(height: 18),
                    _WeeklyAvailability(),
                    SizedBox(height: 18),
                    _SlotPreview(),
                    SizedBox(height: 18),
                    _RulesCard(),
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(_saving ? 'Saving...' : onboarding ? 'Finish setup' : 'Save slots'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppText.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SlotSettingsCard extends StatelessWidget {
  const _SlotSettingsCard();

  static const _durations = [5, 10, 15, 20, 30, 45, 60];
  static const _presets = [
    ('Skin specialist', 20, 1),
    ('General OPD', 15, 1),
    ('Busy clinic', 30, 5),
  ];

  @override
  Widget build(BuildContext context) {
    final c = slotConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Slot settings'),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick setup',
                style: AppText.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _presets)
                    _PresetChip(
                      label:
                          '${p.$1} • ${(60 / p.$2 * p.$3).floor()}/hr',
                      selected: c.slotMinutes == p.$2 && c.capacity == p.$3,
                      onTap: () => c.applyPreset(p.$2, p.$3),
                    ),
                ],
              ),
              const Divider(height: 28, color: Color(0xFFE3E8F2)),
              Text(
                'Slot length',
                style: AppText.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in _durations)
                      FilterPill(
                        label: m == 60 ? '1 hr' : '$m min',
                        selected: c.slotMinutes == m,
                        onTap: () => c.setSlotMinutes(m),
                      ),
                  ],
                ),
              ),
              const Divider(height: 28, color: Color(0xFFE3E8F2)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patients per slot',
                          style: AppText.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Max bookings allowed in one slot',
                          style: AppText.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CountStepper(
                    value: c.capacity,
                    onChanged: c.setCapacity,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: AppText.inter(
                            fontSize: 14,
                            color: AppColors.primaryDark,
                          ),
                          children: [
                            const TextSpan(text: 'You can take '),
                            TextSpan(
                              text: '${c.perHour} appointments / hour',
                              style: AppText.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
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
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mint : AppColors.chipBlueSoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primaryDark : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Text(
            label,
            style: AppText.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chipBlueSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: value > 1 ? () => onChanged(value - 1) : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.remove_rounded,
                size: 20,
                color: value > 1 ? AppColors.textPrimary : AppColors.textFaint,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppText.poppins(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: value < 10 ? () => onChanged(value + 1) : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value < 10
                    ? AppColors.primaryDark
                    : const Color(0xFFB9D5CF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyAvailability extends StatelessWidget {
  const _WeeklyAvailability();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Weekly availability',
          trailing: GestureDetector(
            onTap: () {
              slotConfig.copyDayToAll(1);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Monday copied to all days')),
              );
            },
            child: Text(
              'Copy Monday to all',
              style: AppText.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
        for (var d = 1; d <= 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DayCard(day: d),
          ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final int day;

  Future<TimeRange?> _pick(BuildContext context, TimeRange? initial) async {
    final start = await showTimePicker(
      context: context,
      initialTime: initial?.start ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'SESSION START',
    );
    if (start == null || !context.mounted) return null;
    final end = await showTimePicker(
      context: context,
      initialTime: initial?.end ?? TimeOfDay(hour: (start.hour + 3) % 24, minute: start.minute),
      helpText: 'SESSION END',
    );
    if (end == null) return null;
    final range = TimeRange(start, end);
    if (range.endMin <= range.startMin) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
      }
      return null;
    }
    return range;
  }

  void _conflict(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This session overlaps another session')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = slotConfig.days[day]!;
    final name = weekdayNames[day - 1];
    final count = slotConfig.appointmentsFor(schedule);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      schedule.enabled ? '$count appointments' : 'Day off',
                      style: AppText.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: schedule.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primaryDark,
                onChanged: (v) => slotConfig.setEnabled(day, v),
              ),
            ],
          ),
          if (schedule.enabled) ...[
            const SizedBox(height: 4),
            for (var i = 0; i < schedule.sessions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 6),
                child: _SessionRow(
                  range: schedule.sessions[i],
                  canDelete: schedule.sessions.length > 1,
                  onEdit: () async {
                    final r = await _pick(context, schedule.sessions[i]);
                    if (r == null) return;
                    if (!slotConfig.replaceSession(day, i, r) &&
                        context.mounted) {
                      _conflict(context);
                    }
                  },
                  onDelete: () => slotConfig.removeSession(day, i),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final r = await _pick(context, null);
                  if (r == null) return;
                  if (!slotConfig.addSession(day, r) && context.mounted) {
                    _conflict(context);
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add session'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  textStyle: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.range,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final TimeRange range;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipBlueSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${formatTime(range.start)}  –  ${formatTime(range.end)}',
                  style: AppText.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.edit_outlined,
                size: 17,
                color: AppColors.textMuted,
              ),
              IconButton(
                onPressed: canDelete ? onDelete : null,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: canDelete ? AppColors.textMuted : AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotPreview extends StatelessWidget {
  const _SlotPreview();

  @override
  Widget build(BuildContext context) {
    final dayKey = slotConfig.firstEnabledDay;
    if (dayKey == null) {
      return const SizedBox.shrink();
    }
    final starts = slotConfig.slotStartsFor(slotConfig.days[dayKey]!);
    const maxShown = 12;
    final shown = starts.take(maxShown).toList();
    final more = starts.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Preview • ${weekdayNames[dayKey - 1]}'),
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${starts.length} slots • ${slotConfig.capacity} per slot • '
                '${starts.length * slotConfig.capacity} appointments',
                style: AppText.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in shown)
                    AppChip(
                      label: formatMinutes(s),
                      color: AppColors.mint,
                      textColor: AppColors.primaryDark,
                    ),
                  if (more > 0)
                    AppChip(
                      label: '+$more more',
                      color: AppColors.chipBlue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    final c = slotConfig;

    Widget tile(String title, String sub, bool value, ValueChanged<bool> on) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: AppText.inter(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryDark,
              onChanged: on,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Reminders & rules'),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Column(
            children: [
              tile(
                'Remind patients on the day',
                'WhatsApp / SMS reminder on the appointment date',
                c.remindOnDay,
                (v) => c.setRule(remind: v),
              ),
              const Divider(height: 14, color: Color(0xFFE3E8F2)),
              tile(
                'Notify me about upcoming appointments',
                'Alert before each booked slot',
                c.notifyDoctor,
                (v) => c.setRule(notify: v),
              ),
              const Divider(height: 14, color: Color(0xFFE3E8F2)),
              tile(
                'Allow marking as Missed',
                'Close an appointment if the patient does not visit',
                c.allowMissed,
                (v) => c.setRule(missed: v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
