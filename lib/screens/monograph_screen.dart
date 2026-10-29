import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/favorites.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Full medicine description, opened from "Full Monograph" in the Rx tab.
class MonographScreen extends StatelessWidget {
  const MonographScreen({super.key, required this.remedy});

  final Remedy remedy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            actions: [
              ListenableBuilder(
                listenable: favoriteRemedies,
                builder: (context, _) {
                  final on = favoriteRemedies.contains(remedy.name);
                  return IconButton(
                    tooltip: on ? 'Remove star' : 'Star this medicine',
                    onPressed: () => favoriteRemedies.toggle(remedy.name),
                    icon: Icon(
                      on ? Icons.star_rounded : Icons.star_border_rounded,
                      color: on ? const Color(0xFFFFC94D) : Colors.white,
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 56),
              title: Text(
                remedy.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(56, 84, 20, 54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remedy.common,
                      style: AppText.inter(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _HeaderChip(remedy.type),
                        if (remedy.family != null) _HeaderChip(remedy.family!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                _Section(
                  icon: Icons.hub_outlined,
                  title: 'Overview',
                  child: Column(
                    children: [
                      _InfoRow('Common name', remedy.common),
                      _InfoRow('Type', remedy.type),
                      _InfoRow('Family', remedy.family ?? '-'),
                      _InfoRow('Affinity', remedy.affinity ?? '-', last: true),
                    ],
                  ),
                ),
                _Section(
                  icon: Icons.healing_outlined,
                  title: 'Indications',
                  child: Text(
                    remedy.indications ?? 'Not added yet.',
                    style: AppText.inter(fontSize: 14.5, height: 1.55),
                  ),
                ),
                _Section(
                  icon: Icons.swap_vert_rounded,
                  title: 'Modalities',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Modality(
                          label: 'Worse',
                          icon: Icons.arrow_upward_rounded,
                          text: remedy.worse ?? '-',
                          color: AppColors.danger,
                          bg: AppColors.dangerSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Modality(
                          label: 'Better',
                          icon: Icons.arrow_downward_rounded,
                          text: remedy.better ?? '-',
                          color: AppColors.success,
                          bg: AppColors.successSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                _Section(
                  icon: Icons.science_outlined,
                  title: 'Available potencies',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in remedy.potencies)
                        AppChip(label: p, color: AppColors.mint, textColor: AppColors.primaryDark, bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Information is for the doctor\'s reference. Always use clinical judgement.',
                  textAlign: TextAlign.center,
                  style: AppText.inter(fontSize: 12, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppText.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFEDF0F7))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Modality extends StatelessWidget {
  const _Modality({
    required this.label,
    required this.icon,
    required this.text,
    required this.color,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: AppText.inter(fontSize: 13.5, height: 1.45)),
        ],
      ),
    );
  }
}
