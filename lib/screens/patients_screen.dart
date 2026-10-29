import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/patient_actions.dart';
import '../widgets/common.dart';
import 'add_patient_sheet.dart';
import 'patient_record_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  static const _filters = ['All', 'Recent Visits', 'Family Folders'];

  String _filter = _filters.first;
  String _query = '';

  List<Patient> get _visible {
    final q = _query.trim().toLowerCase();
    final phoneCount = <String, int>{};
    for (final p in clinic.patients) {
      phoneCount[p.phone] = (phoneCount[p.phone] ?? 0) + 1;
    }
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    return clinic.patients.where((p) {
      if (_filter == 'Recent Visits' && (p.lastVisitAt == null || p.lastVisitAt!.isBefore(monthAgo))) {
        return false;
      }
      if (_filter == 'Family Folders' && (phoneCount[p.phone] ?? 0) < 2) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')) ||
          p.id.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => _filter == 'Family Folders'
          ? a.phone.compareTo(b.phone)
          : (b.lastVisitAt ?? DateTime(2000)).compareTo(a.lastVisitAt ?? DateTime(2000)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clinic,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final patients = _visible;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D00695C),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => showAddPatientSheet(context),
          elevation: 0,
          shape: const StadiumBorder(),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Add Patient',
            style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: Column(
        children: [
          const ClinicHeader(section: 'Patients'),
          if (!clinic.loaded) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: clinic.refreshPatients,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (clinic.error != null)
                  ErrorBanner(message: clinic.error!, onRetry: clinic.loadAll),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'MASTER DIRECTORY  ',
                              style: AppText.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            TextSpan(
                              text: '${clinic.registeredCount} Registered',
                              style: AppText.inter(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: AppText.inter(fontSize: 15),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                    hintText: 'Search by name, phone or ID...',
                    hintStyle: AppText.inter(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: _filter == f
                                ? AppColors.mint
                                : AppColors.chipBlue,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => setState(() => _filter = f),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                                child: Text(
                                  f == 'All'
                                      ? 'All (${clinic.registeredCount})'
                                      : f,
                                  style: AppText.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _filter == f
                                        ? AppColors.primaryDark
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (patients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No patients found',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                for (final (i, patient) in patients.indexed)
                  TweenAnimationBuilder<double>(
                    key: ValueKey(patient.dbId),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 280 + (i < 8 ? i * 40 : 0)),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PatientTile(patient: patient),
                    ),
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

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PatientRecordScreen(patient: patient),
        ),
      ),
      child: Row(
        children: [
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${patient.age}y / ${patient.genderShort}',
                      style: AppText.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: '#${patient.id}',
                      color: AppColors.chipBlue,
                      textColor: AppColors.textPrimary,
                      fontSize: 11,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.call_outlined,
                      size: 15,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${patient.phone}  •  Visited ${patient.lastVisit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (patient.lastRemedy != null) ...[
                  const SizedBox(height: 10),
                  RemedyChip(label: patient.lastRemedy!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.chipBlue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => callPatient(context, patient),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.call_outlined,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
