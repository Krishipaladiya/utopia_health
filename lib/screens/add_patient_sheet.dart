import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'patient_record_screen.dart';

/// Register a patient from the clinic side. The mobile number comes first:
/// a patient already seen here, or by another doctor, is found by it.
/// One number can hold several patients (children use a parent's number).
Future<void> showAddPatientSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xCC1B2740),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AddPatientSheet(),
  );
}

class _AddPatientSheet extends StatefulWidget {
  const _AddPatientSheet();

  @override
  State<_AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends State<_AddPatientSheet> {
  static const _relations = ['Self', 'Wife', 'Husband', 'Son', 'Daughter', 'Father', 'Mother', 'Other'];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _complaint = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _diseases = TextEditingController();
  String _gender = 'Male';
  String _relationship = 'Self';
  bool _whatsApp = true;
  bool _more = false;

  PatientLookup? _lookup;
  bool _searching = false;
  String? _usedFrom;

  @override
  void dispose() {
    for (final c in [_name, _phone, _age, _complaint, _email, _address, _diseases]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().length >= 2 && _phone.text.length == 10 && (int.tryParse(_age.text) ?? 0) > 0;

  bool _saving = false;

  Future<void> _onPhone(String v) async {
    setState(() {
      _lookup = null;
      _usedFrom = null;
    });
    if (v.length != 10) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final result = await clinic.lookup(v);
      if (mounted && _phone.text == v) setState(() => _lookup = result);
    } on ApiException {
      // Not found or offline: carry on with a new patient.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _useNetwork(NetworkPatient p) {
    setState(() {
      _name.text = p.name;
      _age.text = '${p.age}';
      _gender = p.gender == 'Female' ? 'Female' : 'Male';
      _email.text = p.email;
      _address.text = p.address;
      _diseases.text = p.otherDiseases;
      _relationship = _relations.contains(p.relationship) ? p.relationship : 'Other';
      _usedFrom = '${p.doctorName} • ${p.clinicName}';
      _more = p.email.isNotEmpty || p.address.isNotEmpty || p.otherDiseases.isNotEmpty;
    });
  }

  void _open(Patient p) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => PatientRecordScreen(patient: p)));
  }

  Future<void> _save({required bool addToQueue}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      await clinic.addPatient(
        name: name,
        phone: _phone.text,
        age: int.parse(_age.text),
        gender: _gender,
        complaint: _complaint.text.trim().isEmpty ? null : _complaint.text.trim(),
        addToQueue: addToQueue,
        whatsAppConsent: _whatsApp,
        details: {
          'email': _email.text.trim(),
          'address': _address.text.trim(),
          'relationship': _relationship,
          'otherDiseases': _diseases.text.trim(),
        },
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(addToQueue ? '$name added to the queue' : '$name added')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final lookup = _lookup;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DAE4),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('New patient', style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            Text(
              'Start with the mobile number. A patient seen before is found automatically.',
              style: AppText.inter(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
            _label('Mobile number'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              onChanged: _onPhone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _decoration('98250 14820', null).copyWith(
                prefixText: '+91  ',
                prefixStyle: AppText.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: lookup == null || lookup.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lookup.inClinic.isNotEmpty) ...[
                          _groupTitle(Icons.family_restroom_rounded, 'Already in your clinic'),
                          for (final p in lookup.inClinic)
                            _foundCard(
                              title: p.name,
                              subtitle: '${p.age}y / ${p.genderShort} • ${p.relationship} • #${p.id}',
                              action: 'Open',
                              onTap: () => _open(p),
                            ),
                          Text(
                            'Adding someone new? Fill the form below. They join the same family folder.',
                            style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                        if (lookup.network.isNotEmpty) ...[
                          _groupTitle(Icons.local_hospital_outlined, 'Seen by other doctors'),
                          for (final p in lookup.network)
                            _foundCard(
                              title: p.name,
                              subtitle: '${p.age}y / ${p.gender == 'Female' ? 'F' : 'M'} • ${p.doctorName}, ${p.clinicName}',
                              action: 'Use',
                              onTap: () => _useNetwork(p),
                            ),
                        ],
                      ],
                    ),
            ),
            if (_usedFrom != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Details filled from $_usedFrom. Drop messages are shared.',
                      style: AppText.inter(fontSize: 12.5, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            _label('Patient name'),
            _field(_name, 'e.g. Rajesh Kumar', Icons.person_outline_rounded, caps: TextCapitalization.words),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Age'),
                      TextField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: _decoration('Years', null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Gender'),
                      Row(
                        children: [
                          for (final g in const ['Male', 'Female'])
                            FilterPill(label: g, selected: _gender == g, onTap: () => setState(() => _gender = g)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _label('Main complaint (optional)'),
            _field(_complaint, 'e.g. Cold & tonsillitis', Icons.healing_outlined, caps: TextCapitalization.sentences),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => setState(() => _more = !_more),
              icon: AnimatedRotation(
                turns: _more ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded),
              ),
              label: Text(_more ? 'Fewer details' : 'More details (relation, email, address)'),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: !_more
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Relation to number owner'),
                        Wrap(
                          spacing: 0,
                          runSpacing: 8,
                          children: [
                            for (final r in _relations)
                              FilterPill(label: r, selected: _relationship == r, onTap: () => setState(() => _relationship = r)),
                          ],
                        ),
                        _label('Email'),
                        _field(_email, 'patient@example.com', Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
                        _label('Address'),
                        _field(_address, 'House, area, city', Icons.home_outlined, caps: TextCapitalization.words),
                        _label('Other diseases'),
                        _field(_diseases, 'e.g. Diabetes, Thyroid', Icons.monitor_heart_outlined, caps: TextCapitalization.sentences),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _whatsApp,
              onChanged: (v) => setState(() => _whatsApp = v ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primaryDark,
              dense: true,
              title: Text(
                'Patient agrees to get prescriptions and reminders on WhatsApp',
                style: AppText.inter(fontSize: 13, height: 1.35, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _valid && !_saving ? () => _save(addToQueue: true) : null,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  disabledBackgroundColor: const Color(0xFFB9D5CF),
                  disabledForegroundColor: Colors.white,
                ),
                icon: const Icon(Icons.how_to_reg_outlined, size: 20),
                label: const Text('Save & add to queue'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: _valid && !_saving ? () => _save(addToQueue: false) : null,
                child: Text(
                  'Save only',
                  style: AppText.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _valid ? AppColors.primaryDark : AppColors.textFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTitle(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Text(text, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
        ),
      );

  Widget _foundCard({
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        children: [
          AvatarCircle(name: title, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextCapitalization caps = TextCapitalization.none,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      textCapitalization: caps,
      keyboardType: keyboard,
      onChanged: (_) => setState(() {}),
      style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _decoration(hint, icon),
    );
  }

  InputDecoration _decoration(String hint, IconData? icon) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.inter(fontSize: 15, color: AppColors.textFaint),
      counterText: '',
      filled: true,
      fillColor: AppColors.chipBlueSoft,
      prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: b(const Color(0xFFDDE3F5)),
      focusedBorder: b(AppColors.primaryDark, 1.6),
    );
  }
}
