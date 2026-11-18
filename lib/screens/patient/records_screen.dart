import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../models/network.dart';
import '../../widgets/common.dart';
import '../content/content_views.dart';
import '../facility/facility_shell.dart' show openReport;

/// Personal medical record: prescriptions and lab tests from every clinic,
/// for every family member on this number.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _member = 'Everyone';
  String _kind = 'Prescriptions';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: patientStore,
      builder: (context, _) {
        final names = {for (final p in patientStore.prescriptions) p.memberName, for (final l in patientStore.labTests) l.memberName};
        final rx = patientStore.prescriptions.where((p) => _member == 'Everyone' || p.memberName == _member).toList();
        final labs = patientStore.labTests.where((l) => _member == 'Everyone' || l.memberName == _member).toList();

        return RefreshIndicator(
          onRefresh: patientStore.refreshRecords,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('My records', style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
              Text('From every clinic, for the whole family', style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final n in ['Everyone', ...names])
                      FilterPill(label: n, selected: _member == n, onTap: () => setState(() => _member = n)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final k in const ['Prescriptions', 'Lab tests'])
                    FilterPill(
                      label: k == 'Prescriptions' ? '$k (${rx.length})' : '$k (${labs.length})',
                      selected: _kind == k,
                      onTap: () => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_kind == 'Prescriptions') ...[
                if (rx.isEmpty) _empty('No prescriptions yet'),
                for (final p in rx) _RxCard(rx: p),
              ] else ...[
                if (labs.isEmpty) _empty('No lab tests yet'),
                for (final l in labs) _LabCard(test: l),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(child: Text(text, style: AppText.inter(color: AppColors.textMuted))),
      );
}

class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx});

  final MyPrescription rx;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${rx.memberName} • ${dayDate(rx.date)}', style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Text('${rx.doctorName} • ${rx.clinicName}', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
            const Divider(height: 20),
            for (final i in rx.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.medication_rounded, size: 18, color: Color(0xFF7C4DFF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: i.name, style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: '\n${i.dose} • ${i.timing} • ${i.course}',
                          style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ])),
                    ),
                  ],
                ),
              ),
            if (rx.notes.isNotEmpty) Text('Advice: ${rx.notes}', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard({required this.test});

  final LabTest test;

  @override
  Widget build(BuildContext context) {
    final ready = test.status == 'ReportReady';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Color(0xFFDFF6F7), shape: BoxShape.circle),
              child: const Icon(Icons.biotech_rounded, color: Color(0xFF00838F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(test.tests, style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('${test.memberName} • ${test.labName} • ${dayDate(test.date)}', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  AppChip(
                    label: test.statusLabel,
                    color: ready ? AppColors.successSoft : AppColors.warningSoft,
                    textColor: ready ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    bold: true,
                  ),
                ],
              ),
            ),
            if (test.hasReport)
              IconButton.filledTonal(
                tooltip: 'Open report',
                onPressed: () => openReport(context, test),
                icon: const Icon(Icons.file_open_outlined),
              ),
          ],
        ),
      ),
    );
  }
}
