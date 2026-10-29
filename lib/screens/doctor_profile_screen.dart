import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'auth/login_screen.dart';
import 'slot_setup_screen.dart';

/// The doctor's own profile: a clear view first, editing on its own page.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log in again with your mobile number, Google or Apple.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    await auth.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _EditProfilePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: ListenableBuilder(
        listenable: Listenable.merge([doctorProfile, slotConfig, clinic]),
        builder: (context, _) {
          final p = doctorProfile;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 270,
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                title: Text('My profile', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                actions: [
                  IconButton(tooltip: 'Edit profile', onPressed: () => _edit(context), icon: const Icon(Icons.edit_outlined)),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
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
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 18),
                        child: Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                              ),
                              child: Text(
                                p.initials,
                                style: AppText.poppins(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(fontSize: 21, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [p.qualification, p.speciality].where((x) => x.isNotEmpty).join(' • ').ifEmpty('Add your qualification'),
                              style: AppText.inter(fontSize: 13.5, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_hospital_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.clinic,
                                    style: AppText.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
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
                    Row(
                      children: [
                        _Stat(value: '${clinic.registeredCount}', label: 'Patients', icon: Icons.groups_rounded),
                        const SizedBox(width: 10),
                        _Stat(value: '${p.experienceYears} yrs', label: 'Experience', icon: Icons.timeline_rounded),
                        const SizedBox(width: 10),
                        _Stat(value: '₹${p.fee}', label: 'Consult fee', icon: Icons.payments_outlined),
                      ],
                    ),
                    if (p.qualification.isEmpty || p.regNo.isEmpty) ...[
                      const SizedBox(height: 14),
                      _CompleteCard(onTap: () => _edit(context)),
                    ],
                    const SizedBox(height: 18),
                    const SectionLabel('Contact & registration'),
                    _Group(children: [
                      _InfoTile(icon: Icons.phone_outlined, label: 'Mobile', value: p.phone),
                      _InfoTile(icon: Icons.mail_outline_rounded, label: 'Email', value: p.email),
                      _InfoTile(icon: Icons.badge_outlined, label: 'Registration no.', value: p.regNo),
                      _InfoTile(icon: Icons.translate_rounded, label: 'Languages', value: p.languages),
                    ]),
                    const SizedBox(height: 18),
                    const SectionLabel('About'),
                    SoftCard(
                      onTap: () => _edit(context),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        p.bio.isEmpty ? 'Add a short introduction for patients.' : p.bio,
                        style: AppText.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: p.bio.isEmpty ? AppColors.textFaint : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionLabel('Clinic settings'),
                    _Group(children: [
                      _LinkTile(
                        icon: Icons.event_available_outlined,
                        title: 'Appointment slots',
                        subtitle: slotConfig.summary,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SlotSetupScreen()),
                        ),
                      ),
                      _LinkTile(
                        icon: Icons.edit_note_rounded,
                        title: 'Edit profile',
                        subtitle: 'Name, qualification, fee and more',
                        onTap: () => _edit(context),
                      ),
                      _LinkTile(
                        icon: Icons.article_outlined,
                        title: 'Articles, blogs & reels',
                        subtitle: 'Publish health content for patients',
                        trailing: 'Soon',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon')),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => _logout(context),
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
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x0F1B2740), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryDark),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            Text(label, style: AppText.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _CompleteCard extends StatelessWidget {
  const _CompleteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete your profile: add qualification and registration number.',
                  style: AppText.inter(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 62, color: Color(0xFFEDF0F7)),
            c,
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.mintSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.inter(fontSize: 12, color: AppColors.textMuted)),
                Text(
                  value.isEmpty ? 'Not added' : value,
                  style: AppText.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty ? AppColors.textFaint : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              AppChip(label: trailing!, fontSize: 11)
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- edit

class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage();

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  static const _qualifications = ['BHMS', 'MBBS', 'BAMS', 'MD', 'MS', 'Other'];

  final p = doctorProfile;
  late final _name = TextEditingController(text: p.name);
  late final _speciality = TextEditingController(text: p.speciality);
  late final _clinic = TextEditingController(text: p.clinic);
  late final _regNo = TextEditingController(text: p.regNo);
  late final _fee = TextEditingController(text: '${p.fee}');
  late final _experience = TextEditingController(text: '${p.experienceYears}');
  late final _languages = TextEditingController(text: p.languages);
  late final _bio = TextEditingController(text: p.bio);
  late String _qualification = p.qualification;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _speciality, _clinic, _regNo, _fee, _experience, _languages, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    doctorProfile.update(
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      qualification: _qualification,
      speciality: _speciality.text.trim(),
      clinic: _clinic.text.trim().isEmpty ? null : _clinic.text.trim(),
      regNo: _regNo.text.trim(),
      fee: int.tryParse(_fee.text) ?? doctorProfile.fee,
      experienceYears: int.tryParse(_experience.text) ?? doctorProfile.experienceYears,
      languages: _languages.text.trim(),
      bio: _bio.text.trim(),
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await runAction(context, doctorProfile.save);
    if (!mounted) return;
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c, IconData icon,
        {bool digits = false, int lines = 1, TextCapitalization caps = TextCapitalization.words}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          minLines: 1,
          maxLines: lines,
          keyboardType: digits ? TextInputType.number : null,
          inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
          textCapitalization: caps,
          style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDDE3F5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.6),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Edit profile', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionLabel('Basic'),
          field('Full name', _name, Icons.person_outline_rounded),
          Text('Qualification', style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 8),
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
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFDDE3F5)),
                  shape: const StadiumBorder(),
                  labelStyle: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _qualification == q ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() => _qualification = q),
                ),
            ],
          ),
          const SizedBox(height: 14),
          field('Speciality', _speciality, Icons.workspace_premium_outlined),
          field('Clinic / hospital', _clinic, Icons.local_hospital_outlined),
          field('Medical registration no.', _regNo, Icons.badge_outlined, caps: TextCapitalization.characters),
          const SizedBox(height: 6),
          const SectionLabel('Practice'),
          Row(
            children: [
              Expanded(child: field('Fee (₹)', _fee, Icons.currency_rupee_rounded, digits: true)),
              const SizedBox(width: 10),
              Expanded(child: field('Experience (yrs)', _experience, Icons.timeline_rounded, digits: true)),
            ],
          ),
          field('Languages', _languages, Icons.translate_rounded),
          field('About you', _bio, Icons.notes_rounded, lines: 5, caps: TextCapitalization.sentences),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving...' : 'Save profile'),
            ),
          ),
        ),
      ),
    );
  }
}
