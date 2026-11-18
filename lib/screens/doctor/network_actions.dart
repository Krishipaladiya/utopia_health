import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../data/clinic_store.dart';
import '../../data/network_stores.dart';
import '../../models/models.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../content/content_views.dart';
import '../facility/facility_shell.dart' show openReport;
import 'team_screen.dart';

/// Sends the patient a one-tap login for the patient app on WhatsApp
/// (from this phone's WhatsApp; no SMS needed).
Future<void> sendAppLoginLink(BuildContext context, Patient patient) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final data = await api.post('/api/patients/${patient.dbId}/app-link') as Map<String, dynamic>;
    final ok = await launchUrl(
      Uri.parse(data['whatsAppUrl'] as String),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok) messenger.showSnackBar(SnackBar(content: Text('Login code for ${patient.name}: ${data['code']}')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
  }
}

/// Opens WhatsApp on this phone with the patient's number and a message that
/// holds the private prescription link; the doctor only taps Send.
Future<void> sendRxOnWhatsApp(BuildContext context, int prescriptionId) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final url = await clinic.shareLink(prescriptionId);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok) messenger.showSnackBar(const SnackBar(content: Text('WhatsApp is not installed on this device.')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
  }
}

/// Right after prescribing: send it on WhatsApp, to a partner clinic, or later.
Future<void> afterPrescribe(BuildContext context, Patient patient, int prescriptionId) async {
  try {
    await teamStore.load();
  } on ApiException {
    // partner list is optional here
  }
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 54),
            ),
            const SizedBox(height: 6),
            Text('Prescription saved', style: AppText.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
            Text('Send it to ${patient.name} on WhatsApp. Just tap Send in WhatsApp.',
                textAlign: TextAlign.center, style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'whatsapp'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), shape: const StadiumBorder()),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send on WhatsApp'),
              ),
            ),
            if (teamStore.partnerClinics.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'clinic'),
                  style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                  icon: const Icon(Icons.local_pharmacy_outlined),
                  label: const Text('Send to partner clinic'),
                ),
              ),
            ],
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'whatsapp') {
    await sendRxOnWhatsApp(context, prescriptionId);
    if (context.mounted && teamStore.partnerClinics.isNotEmpty) await offerSendToClinic(context, prescriptionId);
  } else if (choice == 'clinic') {
    await offerSendToClinic(context, prescriptionId);
  }
}

/// After prescribing: offer to send it to a partner clinic for the medicines.
Future<void> offerSendToClinic(BuildContext context, int prescriptionId) async {
  try {
    await teamStore.load();
  } on ApiException {
    return;
  }
  if (!context.mounted || teamStore.partnerClinics.isEmpty) return;
  final pick = await showModalBottomSheet<Facility>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send to a partner clinic?', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('They get it instantly and prepare the medicines.', style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            for (final f in teamStore.partnerClinics)
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.mint, child: Icon(Icons.local_pharmacy_rounded, color: AppColors.primaryDark)),
                title: Text(f.name),
                subtitle: Text([f.address, f.city].where((x) => x.isNotEmpty).join(', ')),
                onTap: () => Navigator.pop(context, f),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
          ],
        ),
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (await runAction(context, () => teamStore.sendRxToClinic(prescriptionId, pick))) {
    messenger.showSnackBar(SnackBar(content: Text('Sent to ${pick.name}')));
  }
}

/// Order tests at a partner lab, and see this patient's earlier orders and reports.
Future<bool> showLabOrderSheet(BuildContext context, Patient patient) async {
  try {
    await teamStore.load();
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.friendly)));
    return false;
  }
  if (!context.mounted) return false;
  final ordered = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _LabSheet(patient: patient),
  );
  return ordered == true;
}

class _LabSheet extends StatefulWidget {
  const _LabSheet({required this.patient});

  final Patient patient;

  @override
  State<_LabSheet> createState() => _LabSheetState();
}

class _LabSheetState extends State<_LabSheet> {
  static const _common = ['CBC', 'Thyroid profile', 'Lipid profile', 'HbA1c', 'LFT', 'KFT', 'Vitamin D', 'Vitamin B12', 'Urine routine', 'X-ray'];

  final _tests = <String>{};
  final _other = TextEditingController();
  final _notes = TextEditingController();
  Facility? _lab;
  List<LabTest> _history = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lab = teamStore.labs.firstOrNull;
    teamStore.labOrdersFor(widget.patient).then((h) {
      if (mounted) setState(() => _history = h);
    }).catchError((_) {});
  }

  Future<void> _order() async {
    final all = [..._tests, if (_other.text.trim().isNotEmpty) _other.text.trim()];
    if (_lab == null || all.isEmpty) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (await runAction(context, () => teamStore.orderLab(widget.patient, _lab!, all.join(', '), _notes.text.trim()))) {
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text('Tests sent to ${_lab!.name}')));
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lab tests for ${widget.patient.name}', style: AppText.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (teamStore.labs.isEmpty) ...[
              Text('Add a partner laboratory first.', style: AppText.inter(color: AppColors.textMuted)),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeamScreen()));
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add laboratory'),
              ),
            ] else ...[
              Wrap(
                runSpacing: 8,
                children: [
                  for (final l in teamStore.labs) FilterPill(label: l.name, selected: _lab?.id == l.id, onTap: () => setState(() => _lab = l)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _common)
                    FilterChip(
                      label: Text(t),
                      selected: _tests.contains(t),
                      onSelected: (on) => setState(() => on ? _tests.add(t) : _tests.remove(t)),
                    ),
                ],
              ),
              TextField(controller: _other, decoration: const InputDecoration(labelText: 'Other tests')),
              TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes for the lab (optional)')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _order,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_saving ? 'Sending...' : 'Send to lab'),
                ),
              ),
            ],
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionLabel('Earlier tests'),
              for (final h in _history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.biotech_rounded, color: Color(0xFF00838F)),
                  title: Text(h.tests),
                  subtitle: Text('${h.labName} • ${dayDate(h.date)} • ${h.statusLabel}'),
                  trailing: h.hasReport
                      ? IconButton(onPressed: () => openReport(context, h), icon: const Icon(Icons.file_open_outlined))
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
