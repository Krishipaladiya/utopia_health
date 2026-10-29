import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/favorites.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'monograph_screen.dart';

/// Rx tab: searchable list of medicines / materia medica monographs.
class RxScreen extends StatefulWidget {
  const RxScreen({super.key});

  @override
  State<RxScreen> createState() => _RxScreenState();
}

/// Choices from the filter sheet.
class RxFilters {
  const RxFilters({this.types = const {}, this.families = const {}, this.potency, this.sortAz = true});

  final Set<String> types;
  final Set<String> families;
  final String? potency;
  final bool sortAz;

  int get count => types.length + families.length + (potency == null ? 0 : 1) + (sortAz ? 0 : 1);
}

class _RxScreenState extends State<RxScreen> {
  static const _quick = ['All', 'Favorites', 'Polychrests', 'Dilutions', 'Deep Acting'];

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  String _quickFilter = 'All';
  RxFilters _filters = const RxFilters();
  String? _expanded;

  List<Remedy> _remedies = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    favoriteRemedies.load();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.get('/api/remedies', query: {
        'q': _search.text.trim(),
        'take': '200',
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _remedies = (data['items'] as List)
            .map((e) => Remedy.fromJson(e as Map<String, dynamic>))
            .toList();
        _total = data['total'] as int;
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

  void _onSearch(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  /// Closes the keyboard, e.g. when a medicine is tapped.
  void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  List<Remedy> get _visible {
    final list = _remedies.where((r) {
      final ok = switch (_quickFilter) {
        'Favorites' => favoriteRemedies.contains(r.name),
        'Polychrests' => r.type.contains('Polychrest'),
        'Dilutions' => r.type.contains('Dilution'),
        'Deep Acting' => r.type.contains('Deep'),
        _ => true,
      };
      if (!ok) return false;
      if (_filters.types.isNotEmpty && !_filters.types.any(r.type.contains)) return false;
      if (_filters.families.isNotEmpty && !_filters.families.contains(r.family)) return false;
      if (_filters.potency != null && !r.potencies.contains(_filters.potency)) return false;
      return true;
    }).toList();
    list.sort((a, b) => _filters.sortAz ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
    return list;
  }

  Future<void> _openFilters() async {
    _hideKeyboard();
    final result = await showModalBottomSheet<RxFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _FilterSheet(remedies: _remedies, initial: _filters),
    );
    if (result != null) setState(() => _filters = result);
  }

  void _openMonograph(Remedy remedy) {
    _hideKeyboard();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MonographScreen(remedy: remedy)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: favoriteRemedies,
      builder: (context, _) => _buildBody(),
    );
  }

  Widget _buildBody() {
    final list = _visible;
    final filterCount = _filters.count;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _hideKeyboard,
      child: Column(
        children: [
          const ClinicHeader(section: 'Materia Medica'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu_book_outlined, color: AppColors.primaryDark, size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Medicines',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.poppins(fontSize: 17, fontWeight: FontWeight.w600),
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
                          controller: _search,
                          focusNode: _searchFocus,
                          onChanged: _onSearch,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _hideKeyboard(),
                          style: AppText.inter(fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_search.text.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                                    onPressed: () {
                                      _search.clear();
                                      _onSearch('');
                                    },
                                  ),
                                IconButton(
                                  tooltip: 'Filters',
                                  onPressed: _openFilters,
                                  icon: Badge(
                                    isLabelVisible: filterCount > 0,
                                    label: Text('$filterCount'),
                                    backgroundColor: AppColors.primaryDark,
                                    child: Icon(
                                      Icons.tune_rounded,
                                      color: filterCount > 0 ? AppColors.primaryDark : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            hintText: 'Search remedies (e.g. Nux Vomica)',
                            hintStyle: AppText.inter(fontSize: 14, color: AppColors.textMuted),
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
                              for (final f in _quick)
                                FilterPill(
                                  label: f,
                                  icon: f == 'Favorites' ? Icons.star_rounded : null,
                                  selected: _quickFilter == f,
                                  onTap: () {
                                    _hideKeyboard();
                                    setState(() => _quickFilter = f);
                                  },
                                ),
                            ],
                          ),
                        ),
                        if (filterCount > 0) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _filters = const RxFilters()),
                              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                              label: Text('Clear $filterCount filter${filterCount == 1 ? '' : 's'}'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SectionLabel('Clinical monographs', trailing: 'Showing ${list.length} of $_total'),
                  if (_error != null)
                    ErrorBanner(message: _error!, onRetry: _load)
                  else if (_loading && _remedies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          _quickFilter == 'Favorites'
                              ? 'No starred medicines yet. Tap the star on a medicine.'
                              : 'No remedies found',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  for (final remedy in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RemedyTile(
                        remedy: remedy,
                        expanded: _expanded == remedy.name,
                        favorite: favoriteRemedies.contains(remedy.name),
                        onToggle: () {
                          _hideKeyboard();
                          setState(() => _expanded = _expanded == remedy.name ? null : remedy.name);
                        },
                        onFavorite: () => favoriteRemedies.toggle(remedy.name),
                        onOpen: () => _openMonograph(remedy),
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

class _RemedyTile extends StatelessWidget {
  const _RemedyTile({
    required this.remedy,
    required this.expanded,
    required this.favorite,
    required this.onToggle,
    required this.onFavorite,
    required this.onOpen,
  });

  final Remedy remedy;
  final bool expanded;
  final bool favorite;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onToggle,
      borderColor: expanded ? AppColors.primaryDark.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
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
                              style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppChip(label: remedy.type, color: AppColors.mint, textColor: AppColors.primaryDark),
                    ],
                  ),
                ),
                StarButton(active: favorite, onTap: onFavorite),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
            if (expanded) ...[
              const Divider(height: 24, color: Color(0xFFE3E8F2)),
              if (remedy.family != null)
                Text(
                  'Family: ${remedy.family} • Affinity: ${remedy.affinity ?? '-'}',
                  style: AppText.inter(fontSize: 13, height: 1.4, color: AppColors.textMuted),
                ),
              const SizedBox(height: 10),
              Text(
                remedy.indications ?? '-',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.inter(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in remedy.potencies)
                    AppChip(label: p, color: AppColors.chipBlue, textColor: AppColors.textPrimary),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.primaryDark,
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('Full Monograph'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round star toggle for starred medicines.
class StarButton extends StatelessWidget {
  const StarButton({super.key, required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.warningSoft : Colors.transparent,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
          child: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            key: ValueKey(active),
            color: active ? const Color(0xFFF2A100) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.remedies, required this.initial});

  final List<Remedy> remedies;
  final RxFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _types = ['Polychrest', 'Dilution', 'Deep', 'Constitutional', 'Acute', 'Mother Tincture'];

  late final Set<String> _typeSel = {...widget.initial.types};
  late final Set<String> _familySel = {...widget.initial.families};
  late String? _potency = widget.initial.potency;
  late bool _sortAz = widget.initial.sortAz;

  @override
  Widget build(BuildContext context) {
    final families = widget.remedies.map((r) => r.family).whereType<String>().toSet().toList()..sort();
    final potencies = widget.remedies.expand((r) => r.potencies).toSet().toList()..sort();

    Widget group(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        );

    Widget chip(String label, bool selected, VoidCallback onTap) => FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(onTap),
          showCheckmark: false,
          selectedColor: AppColors.mint,
          backgroundColor: AppColors.chipBlueSoft,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          labelStyle: AppText.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filter medicines', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => setState(() {
                    _typeSel.clear();
                    _familySel.clear();
                    _potency = null;
                    _sortAz = true;
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    group('TYPE', [
                      for (final t in _types)
                        chip(t, _typeSel.contains(t), () => _typeSel.contains(t) ? _typeSel.remove(t) : _typeSel.add(t)),
                    ]),
                    group('POTENCY', [
                      for (final p in potencies) chip(p, _potency == p, () => _potency = _potency == p ? null : p),
                    ]),
                    if (families.isNotEmpty)
                      group('FAMILY', [
                        for (final f in families)
                          chip(f, _familySel.contains(f), () => _familySel.contains(f) ? _familySel.remove(f) : _familySel.add(f)),
                      ]),
                    group('SORT', [
                      chip('A to Z', _sortAz, () => _sortAz = true),
                      chip('Z to A', !_sortAz, () => _sortAz = false),
                    ]),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  RxFilters(types: _typeSel, families: _familySel, potency: _potency, sortAz: _sortAz),
                ),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                child: const Text('Show results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
