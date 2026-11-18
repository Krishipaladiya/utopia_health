import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

/// Doctor: partner clinics (get prescriptions), laboratories (get test orders)
/// and the people who log in for them, plus the clinic's front desk.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await teamStore.load();
      if (mounted) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Team & partners', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: ListenableBuilder(
        listenable: teamStore,
        builder: (context, _) {
          final front = teamStore.members.where((m) => m.role == 'reception').toList();
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
                Text(
                  'Everyone here logs in with their own mobile number and sees only their part.',
                  style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Front desk'),
                if (front.isEmpty) _hint('Add a receptionist to manage the queue, patients and fees.'),
                for (final m in front) _PersonTile(person: m),
                const SizedBox(height: 14),
                const SectionLabel('Partner clinics'),
                if (teamStore.partnerClinics.isEmpty) _hint('Add a clinic or medical store. Send prescriptions to it from the patient record.'),
                for (final f in teamStore.partnerClinics) _FacilityCard(facility: f),
                const SizedBox(height: 14),
                const SectionLabel('Laboratories'),
                if (teamStore.labs.isEmpty) _hint('Add a lab. Order tests from the patient record; the lab uploads the report.'),
                for (final f in teamStore.labs) _FacilityCard(facility: f),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppText.inter(fontSize: 13, color: AppColors.textFaint)),
      );

  Future<void> _addSheet(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.support_agent_rounded, color: AppColors.primaryDark),
              title: const Text('Front desk person'),
              subtitle: const Text('Queue, patients, appointments, fees'),
              onTap: () => Navigator.pop(context, 'reception'),
            ),
            ListTile(
              leading: const Icon(Icons.local_pharmacy_outlined, color: AppColors.primaryDark),
              title: const Text('Partner clinic'),
              subtitle: const Text('Receives your prescriptions'),
              onTap: () => Navigator.pop(context, 'clinic'),
            ),
            ListTile(
              leading: const Icon(Icons.biotech_outlined, color: AppColors.primaryDark),
              title: const Text('Laboratory'),
              subtitle: const Text('Receives test orders, uploads reports'),
              onTap: () => Navigator.pop(context, 'lab'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'reception') {
      await showPersonSheet(context, role: 'reception');
    } else {
      await _facilitySheet(context, choice);
    }
  }

  Future<void> _facilitySheet(BuildContext context, String kind) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind == 'lab' ? 'Add laboratory' : 'Add partner clinic', style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(labelText: 'Phone (optional)', prefixText: '+91 '),
            ),
            TextField(controller: address, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Address')),
            TextField(controller: city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final navigator = Navigator.of(context);
                  if (await runAction(context, () => teamStore.addFacility(kind, name.text.trim(), phone.text, address.text.trim(), city.text.trim()))) {
                    navigator.pop();
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds a person who logs in: front desk, or a user of a partner clinic / lab.
Future<void> showPersonSheet(BuildContext context, {required String role, Facility? facility}) {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            facility == null ? 'Add front desk person' : 'Add user for ${facility.name}',
            style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('They log in with a code sent to this email (or their mobile number once SMS is on).',
              style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 '),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email (for login)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || phone.text.length != 10 || !email.text.contains('@')) return;
                final navigator = Navigator.of(context);
                if (await runAction(context, () => teamStore.addMember(name.text.trim(), phone.text, role, facility?.id, email: email.text.trim()))) {
                  navigator.pop();
                }
              },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final users = teamStore.members.where((m) => m.facilityId == facility.id).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: facility.isLab ? const Color(0xFFDFF6F7) : AppColors.mint,
                  child: Icon(
                    facility.isLab ? Icons.biotech_rounded : Icons.local_pharmacy_rounded,
                    color: facility.isLab ? const Color(0xFF00838F) : AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(facility.name, style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(
                        [facility.address, facility.city, facility.phone].where((x) => x.isNotEmpty).join(' • '),
                        style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) => runAction(context, () => teamStore.removeFacility(facility)),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove'))],
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final u in users) _PersonTile(person: u, dense: true),
            TextButton.icon(
              onPressed: () => showPersonSheet(context, role: facility.kind, facility: facility),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add user'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, this.dense = false});

  final TeamPerson person;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      dense: dense,
      contentPadding: dense ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12),
      leading: AvatarCircle(name: person.name, size: dense ? 34 : 40),
      title: Text(person.name),
      subtitle: Text([person.phone, if (person.email.isNotEmpty) person.email, person.roleLabel].join(' • ')),
      trailing: IconButton(
        tooltip: 'Remove',
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: () => runAction(context, () => teamStore.removeMember(person)),
      ),
    );
    return dense ? tile : Padding(padding: const EdgeInsets.only(bottom: 8), child: SoftCard(padding: EdgeInsets.zero, child: tile));
  }
}
