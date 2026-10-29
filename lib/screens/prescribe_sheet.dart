import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';

/// Full-height prescription window. It opens blank: search a medicine, set the
/// dose, add it, and repeat. Nothing is pre-filled.
Future<void> showPrescribeSheet(BuildContext context, Patient patient) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xCC1B2740),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SizedBox(
      height: double.infinity,
      child: _PrescribeSheet(patient: patient),
    ),
  );
}

class _RxItem {
  _RxItem({
    required this.name,
    required this.dose,
    required this.timing,
    required this.course,
  });

  final String name;
  final String dose;
  final String timing;
  final String course;
}

class _PrescribeSheet extends StatefulWidget {
  const _PrescribeSheet({required this.patient});

  final Patient patient;

  @override
  State<_PrescribeSheet> createState() => _PrescribeSheetState();
}

class _PrescribeSheetState extends State<_PrescribeSheet> {
  static const _pillOptions = [2, 4, 6, 8, 10, 12];
  static const _courseOptions = [3, 7, 14, 30];
  static const _times = {
    'Dawn': Icons.wb_twilight_rounded,
    'Noon': Icons.wb_sunny_outlined,
    'Dusk': Icons.wb_sunny_rounded,
    'Moon': Icons.dark_mode_outlined,
  };

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  int _searchSeq = 0;

  final _items = <_RxItem>[];
  List<Remedy> _results = [];
  bool _searching = false;
  String? _searchError;

  // The medicine being configured. Everything starts empty.
  Remedy? _selected;
  String? _potency;
  int? _pills;
  final Set<String> _selectedTimes = {};
  String? _food;
  int? _course;

  bool _sending = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---- search --------------------------------------------------------------

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      _searchSeq++;
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(q.trim()));
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    try {
      final data = await api.get('/api/remedies', query: {'q': q, 'take': '30'}) as Map<String, dynamic>;
      if (!mounted || seq != _searchSeq) return; // a newer search is running
      setState(() {
        _results = (data['items'] as List)
            .map((e) => Remedy.fromJson(e as Map<String, dynamic>))
            .toList();
        _searching = false;
        _searchError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _searchError = e.friendly;
      });
    }
  }

  // ---- configure + add -----------------------------------------------------

  void _select(Remedy r) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = r;
      _potency = null;
      _pills = null;
      _selectedTimes.clear();
      _food = null;
      _course = null;
    });
  }

  void _closeConfigure() => setState(() => _selected = null);

  bool get _canAdd {
    final r = _selected;
    if (r == null) return false;
    final needsPotency = r.potencies.isNotEmpty;
    return (!needsPotency || _potency != null) && _pills != null && _selectedTimes.isNotEmpty;
  }

  void _addItem() {
    final r = _selected;
    if (r == null || !_canAdd) return;
    final order = _times.keys.where(_selectedTimes.contains).join(' • ');
    setState(() {
      _items.add(
        _RxItem(
          name: _potency == null ? r.name : '${r.name} $_potency',
          dose: '$_pills Pills',
          timing: _food == null ? order : '$order ($_food)',
          course: _course == null ? 'As advised' : '$_course Days',
        ),
      );
      _selected = null;
      _search.clear();
      _results = [];
    });
    _searchFocus.requestFocus();
  }

  Future<void> _dispatch() async {
    if (_items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      final status = await clinic.prescribe(widget.patient, [
        for (final i in _items)
          {'name': i.name, 'dose': i.dose, 'timing': i.timing, 'course': i.course},
      ]);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(whatsAppResultMessage(status, widget.patient.name))),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    }
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        children: [
          _header(),
          if (_selected == null) _searchBar(),
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppColors.chipBlueSoft,
              child: _selected != null ? _configurePanel(_selected!) : _searchBody(),
            ),
          ),
          if (_items.isNotEmpty) _itemsStrip(),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prescribe medication',
                  style: AppText.poppins(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${widget.patient.name} • ${widget.patient.age}y / ${widget.patient.genderShort}',
                  style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: _search,
        focusNode: _searchFocus,
        autofocus: true,
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.search,
        style: AppText.inter(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search medicine (e.g. Nux Vomica)',
          hintStyle: AppText.inter(fontSize: 15, color: AppColors.textFaint),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryDark),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _search.clear();
                    _onQueryChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: AppColors.chipBlueSoft,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFDDE3F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _searchBody() {
    final q = _search.text.trim();

    Widget message(IconData icon, String title, String body) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: AppColors.textFaint),
                const SizedBox(height: 12),
                Text(title, style: AppText.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppText.inter(fontSize: 13, height: 1.4, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );

    if (q.isEmpty) {
      return message(
        Icons.medication_outlined,
        _items.isEmpty ? 'No medicines added yet' : '${_items.length} added',
        'Search a medicine above, then set its dose and add it to the prescription.',
      );
    }
    if (_searchError != null) {
      return message(Icons.cloud_off_rounded, 'Search failed', _searchError!);
    }
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return message(Icons.search_off_rounded, 'No medicine found', 'Try a different spelling or the common name.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _results[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _select(r),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${r.common} • ${r.type}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _configurePanel(Remedy r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: AppText.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
                    Text(
                      '${r.common} • ${r.type}',
                      style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _closeConfigure,
                tooltip: 'Back to search',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (r.potencies.isNotEmpty) ...[
            _label('Potency'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in r.potencies)
                  _Choice(label: p, selected: _potency == p, onTap: () => setState(() => _potency = p)),
              ],
            ),
          ],
          _label('Dose (pills)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _pillOptions)
                _Choice(label: '$n', selected: _pills == n, onTap: () => setState(() => _pills = n)),
            ],
          ),
          _label('When'),
          Row(
            children: [
              for (final e in _times.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _TimeTile(
                      label: e.key,
                      icon: e.value,
                      selected: _selectedTimes.contains(e.key),
                      onTap: () => setState(() {
                        if (!_selectedTimes.add(e.key)) _selectedTimes.remove(e.key);
                      }),
                    ),
                  ),
                ),
            ],
          ),
          _label('Food (optional)'),
          Row(
            children: [
              for (final f in const ['Before', 'After'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Choice(
                    label: '$f food',
                    selected: _food == f,
                    onTap: () => setState(() => _food = _food == f ? null : f),
                  ),
                ),
            ],
          ),
          _label('Course (optional)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _courseOptions)
                _Choice(
                  label: '$d days',
                  selected: _course == d,
                  onTap: () => setState(() => _course = _course == d ? null : d),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _canAdd ? _addItem : null,
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                disabledBackgroundColor: const Color(0xFFB9D5CF),
                disabledForegroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(_canAdd ? 'Add to prescription' : 'Choose potency, dose and time'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: AppText.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
      );

  Widget _itemsStrip() {
    return Container(
      height: 62,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = _items[i];
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppText.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      '${item.dose} • ${item.timing}',
                      style: AppText.inter(fontSize: 11, color: AppColors.primaryDark),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => setState(() => _items.removeAt(i)),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.primaryDark),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _footer() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3))],
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          SizedBox(
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.chipBlue,
                foregroundColor: AppColors.textMuted,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text('Discard', style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _items.isEmpty || _sending ? null : _dispatch,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  disabledBackgroundColor: const Color(0xFFB9D5CF),
                  disabledForegroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 19),
                label: Text(
                  _sending
                      ? 'Sending...'
                      : _items.isEmpty
                          ? 'Add a medicine to send'
                          : 'Save & send (${_items.length})',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryDark : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.primaryDark : const Color(0xFFDDE3F5)),
          ),
          child: Text(
            label,
            style: AppText.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textMuted;
    return Material(
      color: selected ? AppColors.primaryDark : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.primaryDark : const Color(0xFFDDE3F5)),
          ),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 4),
              Text(label, style: AppText.inter(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
