import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/patient_actions.dart';
import '../widgets/common.dart';
import '../widgets/record_media.dart';
import 'booking_sheet.dart';
import 'patient_detail_screen.dart';
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
                              itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                                key: ValueKey('${records[i].kind}-${records[i].id}'),
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(milliseconds: 260 + (i < 6 ? i * 50 : 0)),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, child) => Opacity(
                                  opacity: t,
                                  child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
                                ),
                                child: _TimelineItem(
                                  entry: records[i],
                                  isFirst: i == 0,
                                  isLast: i == records.length - 1,
                                  onChanged: _load,
                                ),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
              ),
              child: Row(
                children: [
                  Hero(
                    tag: 'patient-avatar-${patient.dbId}',
                    child: AvatarCircle(name: patient.name, size: 42),
                  ),
                  const SizedBox(width: 10),
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
                Text(
                  'Tap for patient details',
                  style: AppText.inter(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                ),
              ],
            ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Call ${patient.name}',
            onPressed: () => callPatient(context, patient),
            style: IconButton.styleFrom(backgroundColor: AppColors.mint),
            icon: const Icon(Icons.call_rounded, color: AppColors.primaryDark, size: 21),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              if (v == 'details') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
                );
                return;
              }
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
              const PopupMenuItem(value: 'details', child: Text('Patient details')),
              PopupMenuItem(
                value: consent ? 'stop' : 'allow',
                child: Text(consent ? 'Stop WhatsApp messages' : 'Allow WhatsApp messages'),
              ),
            ],
          ),
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
    required this.onChanged,
  });

  final RecordEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onChanged;

  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text('Other doctors will not see it any more.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    if (await runAction(context, () => clinic.deleteNote(entry.id))) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isNote = entry.kind == RecordKind.note || entry.kind == RecordKind.voice;
    final icon = switch (entry.kind) {
      RecordKind.prescription => Icons.description_outlined,
      RecordKind.photo => Icons.image_outlined,
      RecordKind.document => Icons.insert_drive_file_outlined,
      RecordKind.note => Icons.sticky_note_2_outlined,
      RecordKind.voice => Icons.graphic_eq_rounded,
    };

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
                  decoration: BoxDecoration(
                    color: isNote ? const Color(0xFFF2A100) : const Color(0xFFB9C0CC),
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
                onTap: isNote && entry.mine ? () => _delete(context) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
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
                    switch (entry.kind) {
                      RecordKind.prescription => _RxBlock(entry: entry),
                      RecordKind.photo => _PhotoBlock(entry: entry),
                      RecordKind.document => _DocumentBlock(entry: entry),
                      RecordKind.note || RecordKind.voice => _NoteBlock(entry: entry),
                    },
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
    return GestureDetector(
      onTap: () => openImage(context, entry.id, entry.title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Hero(tag: 'record-file-${entry.id}', child: RecordImage(fileId: entry.id)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DocumentBlock extends StatelessWidget {
  const _DocumentBlock({required this.entry});

  final RecordEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipBlueSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openDocument(context, entry.id, entry.title),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDDE3F5)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.chipBlue, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    Text(entry.body, style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: AppColors.primaryDark, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drop message (text or voice) that every doctor treating this patient sees.
class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.entry});

  final RecordEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.mine ? const Color(0xFFFFF8E6) : const Color(0xFFF1F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: entry.mine ? const Color(0xFFF5DFA8) : const Color(0xFFD9E0F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.mine ? Icons.person_rounded : Icons.local_hospital_rounded,
                size: 15,
                color: entry.mine ? AppColors.warning : AppColors.info,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.author ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.mine ? AppColors.warning : AppColors.info,
                  ),
                ),
              ),
              const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textFaint),
              const SizedBox(width: 4),
              Text('All doctors', style: AppText.inter(fontSize: 11, color: AppColors.textFaint)),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.kind == RecordKind.voice)
            VoicePlayer(noteId: entry.id, seconds: entry.seconds)
          else
            Text(entry.body, style: AppText.inter(fontSize: 14, height: 1.45)),
          if (entry.mine) ...[
            const SizedBox(height: 6),
            Text('Tap to delete', style: AppText.inter(fontSize: 11, color: AppColors.textFaint)),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.patient,
    required this.records,
    required this.onChanged,
  });

  final Patient patient;
  final List<RecordEntry> records;
  final VoidCallback onChanged;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final _recorder = VoiceRecorder();
  Timer? _ticker;
  int _recordSeconds = 0;
  bool _recording = false;
  bool _sending = false;

  Patient get patient => widget.patient;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await runAction(context, () => clinic.addNote(patient, text));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _text.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onChanged();
    }
  }

  Future<void> _startRecording() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final started = await _recorder.start();
    if (!started) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Allow the microphone in Settings to record voice messages.')),
      );
      return;
    }
    setState(() {
      _recording = true;
      _recordSeconds = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _ticker?.cancel();
    setState(() => _recording = false);
    if (!send) {
      await _recorder.cancel();
      return;
    }
    final result = await _recorder.stop();
    if (result == null || !mounted) return;
    setState(() => _sending = true);
    final ok = await runAction(context, () => clinic.addVoiceNote(patient, result.$1, result.$2));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) widget.onChanged();
  }

  Future<void> _upload() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (await pickAndUpload(context, patient)) widget.onChanged();
  }

  /// Sends the most recent prescription again on WhatsApp.
  Future<void> _sendLatest() async {
    final latest = widget.records.where((r) => r.kind == RecordKind.prescription).firstOrNull;
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
      widget.onChanged();
    }
  }

  ButtonStyle _chipStyle({Color? bg, Color? fg}) => ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      );

  @override
  Widget build(BuildContext context) {
    final hasText = _text.text.trim().isNotEmpty;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _recording ? _recordingBar() : _inputBar(hasText),
          ),
          const SizedBox(height: 6),
          Text(
            'Drop messages and voice notes are visible to every doctor who treats this patient.',
            textAlign: TextAlign.center,
            style: AppText.inter(fontSize: 11, color: AppColors.textFaint),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await showPrescribeSheet(context, patient);
                    widget.onChanged();
                  },
                  style: _chipStyle(bg: AppColors.aqua, fg: const Color(0xFF004D40)),
                  icon: const Icon(Icons.medication_outlined, size: 19),
                  label: const Text('Prescribe'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _sendLatest,
                  style: _chipStyle(),
                  icon: const Icon(Icons.chat_outlined, size: 19),
                  label: const Text('Send Rx via WhatsApp'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => showBookingSheet(context, patient: patient),
                  style: _chipStyle(bg: AppColors.chipBlue, fg: AppColors.textPrimary),
                  icon: const Icon(Icons.event_available_outlined, size: 19),
                  label: const Text('Book'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _upload,
                  style: _chipStyle(bg: AppColors.chipBlue, fg: AppColors.textPrimary),
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

  Widget _inputBar(bool hasText) {
    return Container(
      key: const ValueKey('input'),
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.chipBlueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE3F5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Photo or document',
            onPressed: _upload,
            icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted),
          ),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: AppText.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Drop a message for all doctors...',
                border: InputBorder.none,
                hintStyle: AppText.inter(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          ),
          if (!hasText) ...[
            Material(
              color: AppColors.chipBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _startRecording,
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.mic_none_rounded, size: 21, color: AppColors.primaryDark),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Material(
            color: hasText ? AppColors.primaryDark : const Color(0xFFB9D5CF),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: hasText && !_sending ? _sendText : null,
              child: SizedBox(
                width: 42,
                height: 42,
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 22, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordingBar() {
    final time = '${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      key: const ValueKey('recording'),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            onPressed: () => _stopRecording(send: false),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          ),
          const _PulsingDot(),
          const SizedBox(width: 8),
          Text(
            'Recording  $time',
            style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _stopRecording(send: true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryDark, shape: const StadiumBorder()),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
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
