import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../data/reminders.dart';
import '../../models/network.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../auth/delete_account.dart';
import '../../widgets/legal.dart';

/// Family members on this mobile number (a mother's number can hold her
/// children), reminders setting and account.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await auth.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([patientStore, medicineReminders]),
      builder: (context, _) {
        final members = patientStore.members;
        return RefreshIndicator(
          onRefresh: patientStore.refreshMembers,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Family',
                style: AppText.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${members.length} member${members.length == 1 ? '' : 's'} on ${session.phone}',
                style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        AvatarCircle(name: m.name, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.name,
                                style: AppText.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${m.relationship} • ${m.age}y / ${m.gender == 'Female' ? 'F' : 'M'}',
                                style: AppText.inter(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              Text(
                                '${m.visits} visit${m.visits == 1 ? '' : 's'} • ${m.clinics} clinic${m.clinics == 1 ? '' : 's'}',
                                style: AppText.inter(
                                  fontSize: 12,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (m.saved)
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => runAction(
                              context,
                              () => patientStore.deleteMember(m),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => showAddMemberSheet(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add family member'),
              ),
              const SizedBox(height: 20),
              const SectionLabel('Settings'),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: patientStore.sharing,
                      onChanged: (v) => runAction(context, () => patientStore.setSharing(v)),
                      secondary: const Icon(Icons.share_outlined, color: AppColors.primaryDark),
                      title: const Text('Share my records between my doctors'),
                      subtitle: const Text(
                        'Doctors you visit on Utopia Health can see each other\'s notes for you and which doctors you see. '
                        'For everyone on this number. You can turn it off any time.',
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: medicineReminders.enabled,
                      onChanged: (v) => medicineReminders.setEnabled(
                        v,
                        patientStore.prescriptions,
                      ),
                      secondary: const Icon(
                        Icons.alarm_rounded,
                        color: AppColors.primaryDark,
                      ),
                      title: const Text('Medicine reminders'),
                      subtitle: const Text(
                        'Alerts at each medicine time, while the course lasts',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Log out',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () => _logout(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Delete account',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () => confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const LegalLinks(),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showAddMemberSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AddMemberSheet(),
  );
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  static const _relations = [
    'Self',
    'Son',
    'Daughter',
    'Wife',
    'Husband',
    'Mother',
    'Father',
    'Other',
  ];

  final _name = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'Male';
  String _relation = 'Son';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final age = int.tryParse(_age.text) ?? 0;
    if (_name.text.trim().length < 2 || age <= 0) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    if (await runAction(
      context,
      () => patientStore.addMember(_name.text.trim(), age, _gender, _relation),
    )) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add family member',
              style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Age (years)',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 8,
              children: [
                for (final r in _relations)
                  FilterPill(
                    label: r,
                    selected: _relation == r,
                    onTap: () => setState(() => _relation = r),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: Text(_saving ? 'Saving...' : 'Save member'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks who a visit or check-in is for. Offers to add a member when there are none.
Future<Member?> pickMember(
  BuildContext context, {
  required String title,
}) async {
  if (patientStore.members.isEmpty) await patientStore.refreshMembers();
  if (!context.mounted) return null;
  if (patientStore.members.isEmpty) {
    await showAddMemberSheet(context);
    if (!context.mounted || patientStore.members.isEmpty) return null;
  }
  if (patientStore.members.length == 1) return patientStore.members.first;
  return showModalBottomSheet<Member>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final m in patientStore.members)
              ListTile(
                leading: AvatarCircle(name: m.name, size: 40),
                title: Text(m.name),
                subtitle: Text('${m.relationship} • ${m.age}y'),
                onTap: () => Navigator.pop(context, m),
              ),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await showAddMemberSheet(context);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Someone else'),
            ),
          ],
        ),
      ),
    ),
  );
}
