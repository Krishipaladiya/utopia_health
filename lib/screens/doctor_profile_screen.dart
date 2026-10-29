import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/doctor_store.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'auth/login_screen.dart';
import 'slot_setup_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  static const _qualifications = ['BHMS', 'MBBS', 'BAMS', 'MD', 'MS', 'Other'];

  final _name = TextEditingController();
  final _speciality = TextEditingController();
  final _clinic = TextEditingController();
  final _regNo = TextEditingController();
  final _fee = TextEditingController();
  final _experience = TextEditingController();
  final _languages = TextEditingController();
  final _bio = TextEditingController();
  String _qualification = 'BHMS';
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = doctorProfile;
    _name.text = p.name;
    _speciality.text = p.speciality;
    _clinic.text = p.clinic;
    _regNo.text = p.regNo;
    _fee.text = '${p.fee}';
    _experience.text = '${p.experienceYears}';
    _languages.text = p.languages;
    _bio.text = p.bio;
    _qualification = p.qualification;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _speciality,
      _clinic,
      _regNo,
      _fee,
      _experience,
      _languages,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    doctorProfile.update(
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      qualification: _qualification,
      speciality: _speciality.text.trim(),
      clinic: _clinic.text.trim().isEmpty ? null : _clinic.text.trim(),
      regNo: _regNo.text.trim(),
      fee: int.tryParse(_fee.text) ?? doctorProfile.fee,
      experienceYears:
          int.tryParse(_experience.text) ?? doctorProfile.experienceYears,
      languages: _languages.text.trim(),
      bio: _bio.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    final ok = await runAction(context, doctorProfile.save);
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
    }
  }

  void _cancel() {
    _load();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([doctorProfile, slotConfig]),
          builder: (context, _) {
            final p = doctorProfile;
            return Column(
              children: [
                _topBar(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _identityCard(p),
                      const SizedBox(height: 14),
                      _statsRow(p),
                      const SizedBox(height: 18),
                      const SectionLabel('Professional details'),
                      _detailsCard(),
                      const SizedBox(height: 18),
                      const SectionLabel('About'),
                      _aboutCard(),
                      const SizedBox(height: 18),
                      const SectionLabel('Appointments'),
                      _linkTile(
                        icon: Icons.event_available_outlined,
                        title: 'Appointment slots',
                        subtitle: slotConfig.summary,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SlotSetupScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _linkTile(
                        icon: Icons.article_outlined,
                        title: 'Articles, blogs & reels',
                        subtitle: 'Publish health content for patients',
                        trailingLabel: 'Soon',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon')),
                        ),
                      ),
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await auth.logout();
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (_) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: Color(0xFFF1C5C5)),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('Log out'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _editing ? _cancel : () => Navigator.of(context).pop(),
            icon: Icon(
              _editing ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
          ),
          Expanded(
            child: Text(
              _editing ? 'Edit profile' : 'My profile',
              style: AppText.poppins(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
          if (_editing)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _editing = true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mint,
                foregroundColor: AppColors.primaryDark,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit',
                style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _identityCard(DoctorProfile p) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.mint,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFEAF7F1)],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x1A00695C), blurRadius: 12),
              ],
            ),
            child: Text(
              p.initials,
              style: AppText.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${p.qualification}${p.speciality.isEmpty ? '' : ' • ${p.speciality}'}',
                  style: AppText.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                const AppChip(
                  label: 'Registration verified',
                  icon: Icons.verified_rounded,
                  color: AppColors.mint,
                  textColor: AppColors.primaryDark,
                  fontSize: 11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(DoctorProfile p) {
    Widget stat(String value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: AppText.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                label,
                style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('142', 'Patients'),
        const SizedBox(width: 10),
        stat('${p.experienceYears} yrs', 'Experience'),
        const SizedBox(width: 10),
        stat('₹${p.fee}', 'Consult fee'),
      ],
    );
  }

  Widget _detailsCard() {
    final p = doctorProfile;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Full name', _name, p.name, Icons.person_outline_rounded),
          _qualificationField(p),
          _field(
            'Speciality',
            _speciality,
            p.speciality,
            Icons.workspace_premium_outlined,
          ),
          _field(
            'Clinic / hospital',
            _clinic,
            p.clinic,
            Icons.local_hospital_outlined,
          ),
          _field(
            'Medical registration no.',
            _regNo,
            p.regNo,
            Icons.badge_outlined,
            caps: TextCapitalization.characters,
          ),
          _readOnlyField('Mobile number', p.phone, Icons.phone_outlined),
          _field(
            'Consultation fee (₹)',
            _fee,
            '₹${p.fee}',
            Icons.currency_rupee_rounded,
            digits: true,
          ),
          _field(
            'Experience (years)',
            _experience,
            '${p.experienceYears} years',
            Icons.timeline_rounded,
            digits: true,
          ),
          _field('Languages', _languages, p.languages, Icons.translate_rounded),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: AppText.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      );

  Widget _field(
    String label,
    TextEditingController controller,
    String shown,
    IconData icon, {
    bool digits = false,
    TextCapitalization caps = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        if (_editing)
          TextField(
            controller: controller,
            keyboardType: digits ? TextInputType.number : null,
            textCapitalization: caps,
            inputFormatters: digits
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: _editDecoration(icon),
          )
        else
          _readRow(shown, icon),
      ],
    );
  }

  Widget _readOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_label(label), _readRow(value, icon)],
    );
  }

  Widget _readRow(String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  InputDecoration _editDecoration(IconData icon) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.chipBlueSoft,
      prefixIcon: Icon(icon, size: 19, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: b(const Color(0xFFDDE3F5)),
      focusedBorder: b(AppColors.primaryDark, 1.6),
    );
  }

  Widget _qualificationField(DoctorProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Qualification'),
        if (_editing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _qualifications)
                ChoiceChip(
                  label: Text(q),
                  selected: _qualification == q,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryDark,
                  backgroundColor: AppColors.chipBlue,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _qualification == q
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() => _qualification = q),
                ),
            ],
          )
        else
          _readRow(p.qualification, Icons.school_outlined),
      ],
    );
  }

  Widget _aboutCard() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: _editing
          ? TextField(
              controller: _bio,
              maxLines: 5,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.inter(fontSize: 14, height: 1.45),
              decoration: _editDecoration(Icons.notes_rounded).copyWith(
                prefixIcon: null,
                contentPadding: const EdgeInsets.all(14),
                hintText: 'Tell patients about your practice',
              ),
            )
          : Text(
              doctorProfile.bio.isEmpty
                  ? 'Add a short introduction for patients.'
                  : doctorProfile.bio,
              style: AppText.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
    );
  }

  Widget _linkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingLabel,
  }) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (trailingLabel != null)
            AppChip(label: trailingLabel, fontSize: 11)
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );
  }
}
