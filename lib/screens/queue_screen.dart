import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/appointments_store.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'add_patient_sheet.dart';
import 'appointments_screen.dart';
import 'patient_record_screen.dart';
import 'prescribe_sheet.dart';

/// Home tab: the patient in room + the live waiting queue.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  bool _showWaiting = true;

  void _openRecord(QueueToken token) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientRecordScreen(
          patient: token.patient,
          token: token.token,
          followUp: token.followUp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clinic,
      builder: (context, _) {
        final current = clinic.current;
        final upcoming = clinic.upcoming;
        final firstWaiting = upcoming
            .where((t) => t.status == QueueStatus.waiting)
            .firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          floatingActionButton: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D00695C),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () => showAddPatientSheet(context),
              elevation: 0,
              shape: const CircleBorder(),
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 32),
            ),
          ),
          body: Column(
            children: [
              const ClinicHeader(showBadge: true),
              if (!clinic.loaded) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: clinic.loadAll,
                  child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (clinic.error != null)
                      ErrorBanner(message: clinic.error!, onRetry: clinic.loadAll),
                    if (current != null)
                      _CurrentPatientCard(
                        token: current,
                        onOpen: () => _openRecord(current),
                        onRx: () => showPrescribeSheet(context, current.patient),
                        onComplete: () => runAction(context, clinic.completeCurrent),
                      )
                    else
                      _EmptyRoomCard(
                        nextLabel: firstWaiting?.patient.name,
                        onCallNext: firstWaiting == null
                            ? null
                            : () => runAction(context, () => clinic.callNext(firstWaiting)),
                      ),
                    const SizedBox(height: 14),
                    const _AppointmentsCard(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _SegmentChip(
                          label: 'Waiting (${upcoming.length})',
                          selected: _showWaiting,
                          onTap: () => setState(() => _showWaiting = true),
                        ),
                        const SizedBox(width: 8),
                        _SegmentChip(
                          label: 'Completed (${clinic.completedToday})',
                          selected: !_showWaiting,
                          onTap: () => setState(() => _showWaiting = false),
                        ),
                        const Spacer(),
                        Text(
                          '~${upcoming.length * 12} min wait',
                          style: AppText.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_showWaiting) ...[
                      if (upcoming.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'No one waiting. New check-ins appear here live.',
                              textAlign: TextAlign.center,
                              style: AppText.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      for (final token in upcoming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _QueueTile(
                            token: token,
                            onTap: () => _openRecord(token),
                            onCallNext: () => runAction(context, () => clinic.callNext(token)),
                          ),
                        ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            '${clinic.completedToday} visits completed today',
                            style: AppText.inter(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                  ],
                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyRoomCard extends StatelessWidget {
  const _EmptyRoomCard({required this.nextLabel, required this.onCallNext});

  final String? nextLabel;
  final VoidCallback? onCallNext;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.mint,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFEAF7F1)],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              color: AppColors.primaryDark,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Room is free',
            style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            nextLabel == null
                ? 'No patient is waiting right now.'
                : 'Next in queue: $nextLabel',
            style: AppText.inter(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCallNext,
              icon: const Icon(Icons.volume_up_outlined, size: 20),
              label: const Text('Call next patient'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                disabledBackgroundColor: const Color(0xFFB9D5CF),
                disabledForegroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPatientCard extends StatelessWidget {
  const _CurrentPatientCard({
    required this.token,
    required this.onOpen,
    required this.onRx,
    required this.onComplete,
  });

  final QueueToken token;
  final VoidCallback onOpen;
  final VoidCallback onRx;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final patient = token.patient;

    return SoftCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.mint,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFEAF7F1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppChip(
                label: 'Token #${token.token.toString().padLeft(2, '0')}',
                color: AppColors.primaryDark,
                textColor: Colors.white,
                bold: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  token.waitLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const AppChip(
                label: 'ACTIVE',
                icon: Icons.circle,
                color: AppColors.mint,
                textColor: AppColors.primaryDark,
                bold: true,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AvatarCircle(name: patient.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            patient.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppChip(
                          label: '${patient.age}y, ${patient.gender}',
                          color: AppColors.chipBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient.complaint,
                      style: AppText.inter(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBlueSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (patient.lastRemedy != null)
                  AppChip(
                    label: patient.lastRemedy!,
                    color: AppColors.mint,
                    textColor: AppColors.primaryDark,
                  ),
                const _Dot(),
                if (token.followUp != null)
                  AppChip(
                    label: 'Follow-up #${token.followUp}',
                    color: AppColors.mint,
                    textColor: AppColors.primaryDark,
                  ),
                const _Dot(),
                if (token.miasm != null)
                  AppChip(
                    label: 'Miasm: ${token.miasm}',
                    color: AppColors.chipBlue,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 11,
                child: ElevatedButton.icon(
                  onPressed: onRx,
                  icon: const Icon(Icons.edit_note_rounded, size: 22),
                  label: const Text('Open Rx Builder'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: AppText.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 10,
                child: OutlinedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Mark Completed'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    backgroundColor: AppColors.mint,
                    side: const BorderSide(color: Color(0xFF9ED3C0)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: AppText.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColors.textFaint,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
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
      color: selected ? AppColors.mint : AppColors.chipBlue,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.token,
    required this.onTap,
    required this.onCallNext,
  });

  final QueueToken token;
  final VoidCallback onTap;
  final VoidCallback onCallNext;

  static const _icons = <String, IconData>{
    'SH-0815': Icons.sentiment_satisfied_alt_outlined,
    'SH-0612': Icons.person_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final patient = token.patient;
    final isScheduled = token.status == QueueStatus.scheduled;

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          AvatarCircle(
            name: patient.name,
            size: 54,
            icon: _icons[patient.id],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppChip(
                      label: token.tokenLabel,
                      color: AppColors.chipBlue,
                      textColor: AppColors.textPrimary,
                      bold: true,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppChip(
                      label: '${patient.age}y, ${patient.genderShort}',
                      color: AppColors.chipBlueSoft,
                      fontSize: 11,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AppChip(
                      label: token.waitLabel,
                      color: isScheduled ? AppColors.chipBlue : AppColors.mint,
                      textColor: isScheduled
                          ? AppColors.textMuted
                          : AppColors.primaryDark,
                      fontSize: 11,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        patient.complaint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isScheduled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.chipBlueSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Scheduled',
                style: AppText.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            Material(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onCallNext,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.volume_up_outlined,
                        size: 17,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Call Next',
                        style: AppText.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Home shortcut: today's booked slots and the next one coming up.
class _AppointmentsCard extends StatelessWidget {
  const _AppointmentsCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appointments,
      builder: (context, _) {
        final booked = appointments.countToday(AppointmentStatus.booked);
        final next = appointments.nextToday;
        final subtitle = next == null
            ? 'Nothing booked for the rest of today'
            : 'Next: ${formatTime(TimeOfDay.fromDateTime(next.start))} • ${next.patient.name}';

        return SoftCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.chipBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's appointments",
                      style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              AppChip(
                label: '$booked booked',
                color: AppColors.mint,
                textColor: AppColors.primaryDark,
                bold: true,
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }
}
