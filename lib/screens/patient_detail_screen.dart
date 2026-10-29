import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/patient_actions.dart';
import '../widgets/common.dart';
import 'patient_record_screen.dart';

/// Everything about one patient: contact, family, health, and the doctors
/// they visit. Opened by tapping the name at the top of the patient record.
class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  PatientProfile? _profile;
  String? _error;

  Patient get _patient => _profile?.patient ?? widget.patient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await clinic.profile(widget.patient);
      if (mounted) setState(() => _profile = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _EditDetailsSheet(patient: _patient),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 250,
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              actions: [
                IconButton(tooltip: 'Edit details', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'patient-avatar-${p.dbId}',
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: AvatarCircle(name: p.name, size: 72),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.poppins(fontSize: 21, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.age} yrs • ${p.gender} • #${p.id} • ${p.relationship}',
                            style: AppText.inter(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _HeaderAction(
                                icon: Icons.call_rounded,
                                label: 'Call',
                                onTap: () => callPatient(context, p),
                              ),
                              const SizedBox(width: 12),
                              _HeaderAction(
                                icon: Icons.folder_shared_outlined,
                                label: 'Record',
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(width: 12),
                              _HeaderAction(icon: Icons.edit_note_rounded, label: 'Edit', onTap: _edit),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(
                children: [
                  if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
                  Row(
                    children: [
                      _Stat(label: 'Patient for', value: durationSince(p.createdAt)),
                      _Stat(label: 'Visits', value: profile == null ? '-' : '${profile.visits}'),
                      _Stat(label: 'Rx', value: profile == null ? '-' : '${profile.prescriptions}'),
                      _Stat(label: 'Files', value: profile == null ? '-' : '${profile.files}'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (p.importantNote.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF5D7A1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.priority_high_rounded, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Important note',
                                  style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning),
                                ),
                                const SizedBox(height: 4),
                                Text(p.importantNote, style: AppText.inter(fontSize: 14, height: 1.45)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  _Card(
                    icon: Icons.contact_phone_outlined,
                    title: 'Contact',
                    children: [
                      _Row(Icons.call_outlined, 'Mobile', '+91 ${p.localPhone}'),
                      _Row(Icons.mail_outline_rounded, 'Email', p.email),
                      _Row(Icons.home_outlined, 'Address', p.address, last: true),
                    ],
                  ),
                  _Card(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Health',
                    children: [
                      _Row(Icons.healing_outlined, 'Complaint', p.complaint),
                      _Row(Icons.coronavirus_outlined, 'Other diseases', p.otherDiseases),
                      _Row(Icons.medication_outlined, 'Last remedy', p.lastRemedy ?? ''),
                      _Row(Icons.event_outlined, 'Last visit', p.lastVisitAt == null ? '' : '${shortDate(p.lastVisitAt!)} (${p.lastVisit})', last: true),
                    ],
                  ),
                  _Card(
                    icon: Icons.family_restroom_rounded,
                    title: 'Family',
                    children: [
                      _Row(Icons.people_outline_rounded, 'Relation', p.relationship),
                      if (p.familyDetails.isNotEmpty) _Row(Icons.notes_rounded, 'Details', p.familyDetails),
                      if (profile != null && profile.family.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No other family members on this number.',
                            style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                      for (final m in profile?.family ?? const <FamilyMember>[])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AvatarCircle(name: m.name, size: 38),
                          title: Text(m.name, style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${m.relationship} • ${m.age}y / ${m.gender == 'Female' ? 'F' : 'M'}',
                            style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            final member = clinic.patients.where((x) => x.dbId == m.id).firstOrNull;
                            if (member == null) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PatientRecordScreen(patient: member)),
                            );
                          },
                        ),
                    ],
                  ),
                  _Card(
                    icon: Icons.route_outlined,
                    title: 'Doctors visited',
                    subtitle: 'Doctors on Utopia Health who treat this patient',
                    children: [
                      if (profile == null)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      for (final (i, d) in (profile?.doctors ?? const <DoctorVisit>[]).indexed)
                        _DoctorTrack(visit: d, last: i == profile!.doctors.length - 1),
                    ],
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F1B2740), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.inter(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.children, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Text(title, style: AppText.poppins(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: AppText.inter(fontSize: 12, color: AppColors.textMuted)),
            ],
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.last = false});

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFEDF0F7))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(width: 104, child: Text(label, style: AppText.inter(fontSize: 13, color: AppColors.textMuted))),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not added' : value,
              style: AppText.inter(
                fontSize: 14,
                fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w600,
                color: value.isEmpty ? AppColors.textFaint : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorTrack extends StatelessWidget {
  const _DoctorTrack({required this.visit, required this.last});

  final DoctorVisit visit;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: visit.isYou ? AppColors.primaryDark : const Color(0xFFB9C0CC),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: last ? Colors.transparent : const Color(0xFFD5DAE4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          visit.doctorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (visit.isYou) ...[
                        const SizedBox(width: 6),
                        const AppChip(label: 'You', color: AppColors.mint, textColor: AppColors.primaryDark, fontSize: 11),
                      ],
                    ],
                  ),
                  Text(
                    [visit.clinicName, if (visit.speciality.isNotEmpty) visit.speciality].join(' • '),
                    style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${visit.visits} visit${visit.visits == 1 ? '' : 's'} • since ${shortDate(visit.firstVisit)}'
                    '${visit.lastVisit == null ? '' : ' • last ${relativeTime(visit.lastVisit)}'}',
                    style: AppText.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditDetailsSheet extends StatefulWidget {
  const _EditDetailsSheet({required this.patient});

  final Patient patient;

  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
  static const _relations = ['Self', 'Wife', 'Husband', 'Son', 'Daughter', 'Father', 'Mother', 'Other'];

  late final _email = TextEditingController(text: widget.patient.email);
  late final _address = TextEditingController(text: widget.patient.address);
  late final _family = TextEditingController(text: widget.patient.familyDetails);
  late final _diseases = TextEditingController(text: widget.patient.otherDiseases);
  late final _note = TextEditingController(text: widget.patient.importantNote);
  late String _relation = _relations.contains(widget.patient.relationship) ? widget.patient.relationship : 'Other';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_email, _address, _family, _diseases, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await runAction(context, () async {
      await clinic.saveDetails(widget.patient, {
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'relationship': _relation,
        'familyDetails': _family.text.trim(),
        'otherDiseases': _diseases.text.trim(),
        'importantNote': _note.text.trim(),
      });
    });
    if (ok) {
      navigator.pop(true);
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c, IconData icon, {int lines = 1, TextInputType? type}) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          minLines: 1,
          maxLines: lines,
          keyboardType: type,
          textCapitalization: type == null ? TextCapitalization.sentences : TextCapitalization.none,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: AppColors.chipBlueSoft,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Patient details', style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Relation to number owner', style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 8,
              children: [
                for (final r in _relations)
                  FilterPill(label: r, selected: _relation == r, onTap: () => setState(() => _relation = r)),
              ],
            ),
            field('Email', _email, Icons.mail_outline_rounded, type: TextInputType.emailAddress),
            field('Address', _address, Icons.home_outlined, lines: 3),
            field('Family details', _family, Icons.family_restroom_rounded, lines: 3),
            field('Other diseases', _diseases, Icons.monitor_heart_outlined, lines: 3),
            field('Important note', _note, Icons.priority_high_rounded, lines: 4),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: Text(_saving ? 'Saving...' : 'Save details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
