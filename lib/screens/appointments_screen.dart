import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/appointments_store.dart';
import '../data/doctor_store.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'booking_sheet.dart';

/// Doctor's appointment list: booked slots per day, book, check in, missed.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    appointments.selectDate(DateTime.now());
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required Future<void> Function() run,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) await runAction(context, run);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBookingSheet(context, date: appointments.selectedDate),
        elevation: 2,
        shape: const StadiumBorder(),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Book', style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: appointments,
          builder: (context, _) {
            final list = appointments.selected;
            int count(AppointmentStatus s) => list.where((a) => a.status == s).length;

            return Column(
              children: [
                _header(context),
                _dateStrip(),
                if (appointments.loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: appointments.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                      children: [
                        if (appointments.error != null)
                          ErrorBanner(message: appointments.error!, onRetry: appointments.refresh),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppChip(
                              label: 'Booked ${count(AppointmentStatus.booked)}',
                              color: AppColors.mint,
                              textColor: AppColors.primaryDark,
                              bold: true,
                            ),
                            AppChip(label: 'Checked in ${count(AppointmentStatus.done)}'),
                            AppChip(
                              label: 'Missed ${count(AppointmentStatus.missed)}',
                              color: AppColors.dangerSoft,
                              textColor: AppColors.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (list.isEmpty && !appointments.loading)
                          _empty(context),
                        for (final a in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AppointmentTile(
                              appointment: a,
                              isToday: appointments.selectedIsToday,
                              onCheckIn: () => runAction(context, () => appointments.checkIn(a)),
                              onMissed: () => _confirm(
                                context,
                                title: 'Mark as missed?',
                                body: '${a.patient.name} did not visit. The appointment will be closed.',
                                action: 'Mark missed',
                                run: () => appointments.markMissed(a),
                              ),
                              onCancel: () => _confirm(
                                context,
                                title: 'Cancel appointment?',
                                body: 'The slot at ${formatTime(TimeOfDay.fromDateTime(a.start))} will be free again.',
                                action: 'Cancel it',
                                run: () => appointments.cancel(a),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appointments',
                  style: AppText.poppins(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                Text(
                  appointments.selectedIsToday
                      ? 'Today • ${dayLabel(appointments.selectedDate)}'
                      : dayLabel(appointments.selectedDate),
                  style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const DoctorAvatar(),
        ],
      ),
    );
  }

  Widget _dateStrip() {
    final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      color: Colors.white,
      height: 78,
      padding: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = start.add(Duration(days: i));
          final selected = d == appointments.selectedDate;
          return GestureDetector(
            onTap: () => appointments.selectDate(d),
            child: Container(
              width: 54,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : AppColors.chipBlueSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Today' : wd[d.weekday - 1],
                    style: AppText.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: AppText.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.chipBlue, shape: BoxShape.circle),
            child: const Icon(Icons.event_note_outlined, size: 32, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'No appointments on this day',
            style: AppText.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap Book to add one from your free slots.',
            style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.isToday,
    required this.onCheckIn,
    required this.onMissed,
    required this.onCancel,
  });

  final Appointment appointment;
  final bool isToday;
  final VoidCallback onCheckIn;
  final VoidCallback onMissed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final p = a.patient;
    final time = TimeOfDay.fromDateTime(a.start);
    final booked = a.status == AppointmentStatus.booked;
    final overdue = booked &&
        isToday &&
        a.start.add(Duration(minutes: slotConfig.slotMinutes)).isBefore(DateTime.now());

    final (label, bg, fg) = switch (a.status) {
      AppointmentStatus.booked => overdue
          ? ('Overdue', AppColors.warningSoft, AppColors.warning)
          : ('Booked', AppColors.mint, AppColors.primaryDark),
      AppointmentStatus.done => ('Checked in', AppColors.successSoft, AppColors.success),
      AppointmentStatus.missed => ('Missed', AppColors.dangerSoft, AppColors.danger),
      AppointmentStatus.cancelled => ('Cancelled', AppColors.chipBlue, AppColors.textMuted),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                Text(
                  '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')}',
                  style: AppText.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: booked ? AppColors.textPrimary : AppColors.textFaint,
                  ),
                ),
                Text(
                  time.period == DayPeriod.am ? 'AM' : 'PM',
                  style: AppText.inter(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarCircle(name: p.name, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${p.age}y / ${p.genderShort} • ${p.complaint}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppChip(label: label, color: bg, textColor: fg, fontSize: 11, bold: true),
                  ],
                ),
                if (booked) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isToday)
                        Expanded(
                          flex: 5,
                          child: ElevatedButton.icon(
                            onPressed: onCheckIn,
                            icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                            label: const Text('Check in'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: const StadiumBorder(),
                              textStyle: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      if (isToday) const SizedBox(width: 8),
                      if (isToday)
                        Expanded(
                          flex: 4,
                          child: OutlinedButton(
                            onPressed: onMissed,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: Color(0xFFF1C5C5)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: const StadiumBorder(),
                              textStyle: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Missed'),
                          ),
                        ),
                      if (!isToday) const Spacer(),
                      IconButton(
                        onPressed: onCancel,
                        tooltip: 'Cancel appointment',
                        icon: const Icon(Icons.event_busy_outlined, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
