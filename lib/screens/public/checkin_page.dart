import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../auth/auth_widgets.dart';
import '../patient/patient_shell.dart';
import '../patient/scan_screen.dart' show showTokenDialog;

/// Opened by scanning the clinic's QR with any phone camera:
/// mobile number → SMS code → name → token. No app or account needed.
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, required this.code});

  final String code;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'Male';
  Map<String, dynamic>? _clinic;
  String? _error;
  bool _codeSent = false;
  bool _busy = false;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _load();
    AppSession.lastPhone().then((p) {
      if (mounted && p.length == 10) setState(() => _phone.text = p);
    });
  }

  Future<void> _load() async {
    try {
      final c = await api.get('/api/public/clinics/${widget.code}') as Map<String, dynamic>;
      if (mounted) setState(() => _clinic = c);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.code == 'clinic_not_found' ? 'This QR code is not active.' : e.friendly);
    }
  }

  Future<void> _sendCode() async {
    if (_phone.text.length != 10) return;
    setState(() => _busy = true);
    try {
      _devCode = await auth.sendOtp(_phone.text);
      setState(() => _codeSent = true);
    } on ApiException catch (e) {
      setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getToken() async {
    final age = int.tryParse(_age.text) ?? 0;
    if (_otp.text.length != 6 || _name.text.trim().length < 2 || age <= 0) {
      setState(() => _error = 'Fill your name, age and the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await api.post('/api/public/checkin', {
        'code': widget.code,
        'phone': _phone.text,
        'otp': _otp.text,
        'name': _name.text.trim(),
        'age': age,
        'gender': _gender,
      }) as Map<String, dynamic>;
      TextInput.finishAutofillContext();
      await AppSession.rememberPhone(_phone.text);
      // Signed in as the patient, so they can follow their turn.
      await api.saveSession(data['authToken'] as String);
      session.apply({'role': 'patient', 'phone': '+91${_phone.text}'});
      if (!mounted) return;
      await showTokenDialog(context, data['result'] as Map<String, dynamic>);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PatientShell()), (_) => false);
    } on ApiException catch (e) {
      setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _clinic;
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthHeading(
              title: c == null ? 'Get your token' : c['name'] as String,
              subtitle: c == null
                  ? 'Loading clinic...'
                  : '${c['doctorName']} • ${(c['waiting'] as int) == 0 ? 'No one waiting' : '${c['waiting']} waiting'}',
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
              ),
            const FieldLabel('Mobile number'),
            PhoneField(controller: _phone, onChanged: (v) {
              setState(() => _codeSent = false);
              if (v.length == 10) _sendCode();
            }),
            if (_codeSent) ...[
              const FieldLabel('SMS code'),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 6),
                decoration: authInputDecoration(hint: '6-digit code', icon: Icons.sms_outlined),
              ),
              if (_devCode != null)
                Text('Development server: any 6 digits work', style: AppText.inter(fontSize: 11.5, color: AppColors.textFaint)),
              const FieldLabel('Patient name'),
              AuthTextField(controller: _name, hint: 'Full name', icon: Icons.person_outline_rounded, autofillHints: const [AutofillHints.name]),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Age'),
                        TextField(
                          controller: _age,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                          decoration: authInputDecoration(hint: 'Years'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Gender'),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Male', label: Text('M')),
                            ButtonSegment(value: 'Female', label: Text('F')),
                          ],
                          selected: {_gender},
                          onSelectionChanged: (s) => setState(() => _gender = s.first),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _busy ? 'Please wait...' : 'Get my token',
                icon: Icons.confirmation_number_outlined,
                onPressed: _busy ? null : _getToken,
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                _busy ? 'Sending code...' : 'We send a code by SMS as soon as you enter 10 digits.',
                style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
