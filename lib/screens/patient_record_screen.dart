import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'booking_sheet.dart';
import 'prescribe_sheet.dart';

/// Patient record: timeline of prescriptions/uploads + dictation composer.
/// Opened from the Home queue or the Patients directory.
class PatientRecordScreen extends StatefulWidget {
  const PatientRecordScreen({
    super.key,
    required this.patient,
    this.token,
    this.followUp,
  });

  final Patient patient;
  final int? token;
  final int? followUp;

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  List<RecordEntry> _records = [];
  late bool _consent = widget.patient.whatsAppConsent;
  bool _loading = true;
  String? _error;

  Patient get patient => widget.patient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await clinic.records(patient, doctorProfile.clinic);
      if (!mounted) return;
      setState(() {
        _records = list;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.friendly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final inConsult = widget.token != null;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _RecordHeader(
              patient: patient,
              token: widget.token,
              followUp: widget.followUp,
              inConsult: inConsult,
              consent: _consent,
              onConsentChanged: (v) => setState(() => _consent = v),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorBanner(message: _error!, onRetry: _load),
                        )
                      : records.isEmpty
                          ? const _EmptyRecord()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                              itemCount: records.length,
                              itemBuilder: (_, i) => _TimelineItem(
                                entry: records[i],
                                isFirst: i == 0,
                                isLast: i == records.length - 1,
                              ),
                            ),
            ),
            _Composer(patient: patient, records: records, onChanged: _load),
          ],
        ),
      ),
    );
  }
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({
    required this.patient,
    required this.token,
    required this.followUp,
    required this.inConsult,
    required this.consent,
    required this.onConsentChanged,
  });

  final Patient patient;
  final int? token;
  final int? followUp;
  final bool inConsult;
  final bool consent;
  final ValueChanged<bool> onConsentChanged;

  @override
  Widget build(BuildContext context) {
    final meta = StringBuffer('${patient.age}y/${patient.genderShort}');
    if (followUp != null) meta.write('  •  Follow-up #$followUp');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 26),
          ),
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
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (token != null) ...[
                      const SizedBox(width: 8),
                      AppChip(
                        label:
                            'Token #${token!.toString().padLeft(2, '0')}',
                        color: AppColors.chipBlue,
                        textColor: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        meta.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (inConsult) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'In Consult',
                        style: AppText.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              final allow = v == 'allow';
              final ok = await runAction(
                context,
                () => clinic.setWhatsAppConsent(patient, allow),
              );
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      allow
                          ? 'WhatsApp messages turned on for ${patient.name}'
                          : 'WhatsApp messages turned off for ${patient.name}',
                    ),
                  ),
                );
                onConsentChanged(allow);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: consent ? 'stop' : 'allow',
                child: Text(consent ? 'Stop WhatsApp messages' : 'Allow WhatsApp messages'),
              ),
            ],
          ),
          const DoctorAvatar(),
        ],
      ),
    );
  }
}

class _EmptyRecord extends StatelessWidget {
  const _EmptyRecord();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.chipBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 32,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No records yet',
              style: AppText.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Type or dictate an observation, prescribe, or upload a report to start this case.',
              textAlign: TextAlign.center,
              style: AppText.inter(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final RecordEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isRx = entry.kind == RecordKind.prescription;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB9C0CC),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : const Color(0xFFD5DAE4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRx
                              ? Icons.description_outlined
                              : Icons.image_outlined,
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.header,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        AppChip(
                          label: entry.date,
                          color: AppColors.chipBlue,
                          textColor: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isRx) _RxBlock(entry: entry) else _PhotoBlock(entry: entry),
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

class _RxBlock extends StatelessWidget {
  const _RxBlock({required this.entry});

  final RecordEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipBlueSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medication_outlined,
                size: 17,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.title,
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              _DeliveryChip(status: entry.delivery),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppText.inter(fontSize: 14, height: 1.4),
              children: [
                TextSpan(
                  text: 'Rx: ',
                  style: AppText.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: entry.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({required this.entry});

  final RecordEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chipBlueSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3F5)),
      ),
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
              Icons.photo_camera_outlined,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: AppText.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.body,
                  style: AppText.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.north_east_rounded,
            color: AppColors.primaryDark,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.patient,
    required this.records,
    required this.onChanged,
  });

  final Patient patient;
  final List<RecordEntry> records;
  final VoidCallback onChanged;

  /// Sends the most recent prescription again on WhatsApp.
  Future<void> _sendLatest(BuildContext context) async {
    final latest =
        records.where((r) => r.kind == RecordKind.prescription).firstOrNull;
    if (latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a prescription first')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    String? status;
    final ok = await runAction(context, () async {
      status = await clinic.resendPrescription(latest.id);
    });
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text(whatsAppResultMessage(status, patient.name))));
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: AppColors.chipBlueSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDDE3F5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: AppText.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type observation or dictation...',
                      border: InputBorder.none,
                      hintStyle: AppText.inter(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.chipBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_none_rounded,
                    size: 21,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await showPrescribeSheet(context, patient);
                    onChanged();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.aqua,
                    foregroundColor: const Color(0xFF004D40),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  icon: const Icon(Icons.medication_outlined, size: 19),
                  label: const Text('Prescribe'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _sendLatest(context),
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 19),
                  label: const Text('Send Rx via WhatsApp'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => showBookingSheet(context, patient: patient),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chipBlue,
                    foregroundColor: AppColors.textPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  icon: const Icon(Icons.event_available_outlined, size: 19),
                  label: const Text('Book'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chipBlue,
                    foregroundColor: AppColors.textPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 19),
                  label: const Text('Upload'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// WhatsApp delivery state of a prescription.
class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (status) {
      'Queued' => ('Sending', Icons.schedule_rounded, AppColors.chipBlue, AppColors.textMuted),
      'Sent' => ('Sent', Icons.done_rounded, AppColors.chipBlue, AppColors.textMuted),
      'Delivered' => ('Delivered', Icons.done_all_rounded, AppColors.mint, AppColors.primaryDark),
      'Read' => ('Read', Icons.done_all_rounded, AppColors.successSoft, AppColors.success),
      'Failed' => ('Not delivered', Icons.error_outline_rounded, AppColors.dangerSoft, AppColors.danger),
      'Skipped' => ('No consent', Icons.block_rounded, AppColors.warningSoft, AppColors.warning),
      _ => ('Not sent', Icons.chat_bubble_outline_rounded, AppColors.chipBlue, AppColors.textMuted),
    };
    return AppChip(label: label, icon: icon, color: bg, textColor: fg, fontSize: 11, bold: true);
  }
}
