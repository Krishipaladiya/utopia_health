import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

/// Rx tab: searchable list of medicines / materia medica monographs.
class RxScreen extends StatefulWidget {
  const RxScreen({super.key});

  @override
  State<RxScreen> createState() => _RxScreenState();
}

class _RxScreenState extends State<RxScreen> {
  static const _filters = [
    'Favorites',
    'All',
    'Polychrests',
    'Dilutions',
    'Deep Acting',
  ];

  String _filter = 'All';
  String _query = '';
  String? _expanded;
  final Set<String> _favorites = {};

  List<Remedy> _remedies = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.get('/api/remedies') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _remedies = (data['items'] as List)
            .map((e) => Remedy.fromJson(e as Map<String, dynamic>))
            .toList();
        _total = data['total'] as int;
        _expanded = _remedies.isEmpty ? null : _remedies.first.name;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.friendly;
        _loading = false;
      });
    }
  }

  List<Remedy> get _visible {
    return _remedies.where((r) {
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty &&
          !r.name.toLowerCase().contains(q) &&
          !r.common.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case 'Favorites':
          return _favorites.contains(r.name);
        case 'Polychrests':
          return r.type.contains('Polychrest');
        case 'Dilutions':
          return r.type.contains('Dilution');
        case 'Deep Acting':
          return r.type.contains('Deep');
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Column(
      children: [
        const ClinicHeader(section: 'Materia Medica'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              SoftCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.primaryDark,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Medicines & Materia',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppChip(
                          label: '$_total Remedies',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.mint,
                          textColor: AppColors.primaryDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: AppText.inter(fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.textMuted,
                        ),
                        hintText: 'Search remedies (e.g. Nux Vomica)',
                        hintStyle: AppText.inter(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.chipBlue,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
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
                            FilterPill(
                              label: f,
                              icon: f == 'Favorites'
                                  ? Icons.star_border_rounded
                                  : null,
                              selected: _filter == f,
                              onTap: () => setState(() => _filter = f),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SectionLabel(
                'Clinical monographs',
                trailing: 'Showing ${list.length} of $_total',
              ),
              if (_error != null)
                ErrorBanner(message: _error!, onRetry: _load)
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No remedies found',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              for (final remedy in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RemedyTile(
                    remedy: remedy,
                    expanded: _expanded == remedy.name,
                    favorite: _favorites.contains(remedy.name),
                    onToggle: () => setState(
                      () => _expanded =
                          _expanded == remedy.name ? null : remedy.name,
                    ),
                    onFavorite: () => setState(() {
                      if (!_favorites.add(remedy.name)) {
                        _favorites.remove(remedy.name);
                      }
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RemedyTile extends StatelessWidget {
  const _RemedyTile({
    required this.remedy,
    required this.expanded,
    required this.favorite,
    required this.onToggle,
    required this.onFavorite,
  });

  final Remedy remedy;
  final bool expanded;
  final bool favorite;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onToggle,
      borderColor: expanded ? AppColors.primaryDark.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: remedy.name,
                            style: AppText.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: '  (${remedy.common})',
                            style: AppText.inter(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppChip(
                      label: remedy.type,
                      color: AppColors.mint,
                      textColor: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onFavorite,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: favorite ? AppColors.mint : Colors.transparent,
                  ),
                  child: Icon(
                    favorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: favorite
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
          if (expanded) ...[
            const Divider(height: 24, color: Color(0xFFE3E8F2)),
            if (remedy.family != null)
              Text(
                'Family: ${remedy.family} • Affinity: ${remedy.affinity}',
                style: AppText.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Indications:',
              child: Text(
                remedy.indications ?? '-',
                style: AppText.inter(fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Modalities:',
              child: Text.rich(
                TextSpan(
                  style: AppText.inter(fontSize: 14, height: 1.4),
                  children: [
                    TextSpan(
                      text: 'Worse: ',
                      style: AppText.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                    TextSpan(text: '${remedy.worse ?? '-'} '),
                    TextSpan(
                      text: 'Better: ',
                      style: AppText.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    TextSpan(text: remedy.better ?? '-'),
                  ],
                ),
              ),
            ),
            const Divider(height: 26, color: Color(0xFFE3E8F2)),
            Row(
              children: [
                Text(
                  'Potencies:',
                  style: AppText.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in remedy.potencies)
                        AppChip(
                          label: p,
                          color: AppColors.chipBlue,
                          textColor: AppColors.textPrimary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Full Monograph',
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
