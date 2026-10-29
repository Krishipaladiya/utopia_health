import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

/// Register a patient from the clinic side. One mobile number can hold
/// several patients (children use a parent's number).
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
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _complaint = TextEditingController();
  String _gender = 'Male';
  bool _whatsApp = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _age, _complaint]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().length >= 2 &&
      _phone.text.length == 10 &&
      (int.tryParse(_age.text) ?? 0) > 0;

  bool _saving = false;

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
        complaint:
            _complaint.text.trim().isEmpty ? null : _complaint.text.trim(),
        addToQueue: addToQueue,
        whatsAppConsent: _whatsApp,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(addToQueue ? '$name added to the queue' : '$name added'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final family =
        _phone.text.length == 10 ? clinic.patientWithPhone(_phone.text) : null;

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
                  child: Text(
                    'New patient',
                    style: AppText.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            _label('Patient name'),
            _field(
              _name,
              'e.g. Rajesh Kumar',
              Icons.person_outline_rounded,
              caps: TextCapitalization.words,
            ),
            _label('Mobile number'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _decoration('98250 14820', null).copyWith(
                prefixText: '+91  ',
                prefixStyle: AppText.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (family != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.mint),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.family_restroom_rounded,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This number is already used by ${family.name}. '
                        'This patient will join the same family folder.',
                        style: AppText.inter(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AppText.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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
                            FilterPill(
                              label: g,
                              selected: _gender == g,
                              onTap: () => setState(() => _gender = g),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _label('Main complaint (optional)'),
            _field(
              _complaint,
              'e.g. Cold & tonsillitis',
              Icons.healing_outlined,
              caps: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
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
                    color: _valid
                        ? AppColors.primaryDark
                        : AppColors.textFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          text,
          style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    TextCapitalization caps = TextCapitalization.none,
  }) {
    return TextField(
      controller: c,
      textCapitalization: caps,
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
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: b(const Color(0xFFDDE3F5)),
      focusedBorder: b(AppColors.primaryDark, 1.6),
    );
  }
}
