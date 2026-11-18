import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../content/content_views.dart';
import 'family_screen.dart';

/// Explore: clinics nearest first with the live waiting time, doctors' blogs
/// and health camps.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _tab = 'Clinics';
  final _search = TextEditingController();
  Timer? _debounce;
  Position? _pos;
  List<ClinicCard> _clinics = [];
  List<BlogPost> _posts = [];
  List<Camp> _camps = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locateAndLoad();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _locateAndLoad() async {
    _pos = await currentPosition();
    await _load();
  }

  Map<String, String?> get _where => {
        'lat': _pos?.latitude.toString(),
        'lng': _pos?.longitude.toString(),
      };

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.get('/api/explore/clinics', query: {..._where, 'q': _search.text.trim()}),
        api.get('/api/explore/posts'),
        api.get('/api/explore/camps', query: _where),
      ]);
      if (!mounted) return;
      setState(() {
        _clinics = (results[0] as List).map((e) => ClinicCard.fromJson(e as Map<String, dynamic>)).toList();
        _posts = (results[1] as List).map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
        _camps = (results[2] as List).map((e) => Camp.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.friendly;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text('Explore', style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(
            _pos == null ? 'Turn on location to see the nearest first' : 'Nearest first, with live waiting time',
            style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              hintText: 'Doctor, clinic, speciality or city',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Use my location',
                onPressed: _locateAndLoad,
                icon: Icon(Icons.my_location_rounded, color: _pos == null ? AppColors.textMuted : AppColors.primaryDark),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final t in const ['Clinics', 'Health camps', 'Blogs'])
                FilterPill(label: t, selected: _tab == t, onTap: () => setState(() => _tab = t)),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey(_tab), child: _tabBody()),
          ),
        ],
      ),
    );
  }

  Widget _tabBody() {
    Widget empty(String text) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text(text, style: AppText.inter(color: AppColors.textMuted))),
        );
    switch (_tab) {
      case 'Health camps':
        if (!_loading && _camps.isEmpty) return empty('No upcoming health camps');
        return Column(children: [for (final c in _camps) Padding(padding: const EdgeInsets.only(bottom: 10), child: CampCard(camp: c))]);
      case 'Blogs':
        if (!_loading && _posts.isEmpty) return empty('No blogs yet');
        return Column(children: [for (final p in _posts) Padding(padding: const EdgeInsets.only(bottom: 12), child: BlogCard(post: p))]);
      default:
        if (!_loading && _clinics.isEmpty) return empty('No clinics found');
        return Column(children: [for (final c in _clinics) _ClinicTile(clinic: c)]);
    }
  }
}

class _ClinicTile extends StatelessWidget {
  const _ClinicTile({required this.clinic});

  final ClinicCard clinic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClinicDetailScreen(clinicId: clinic.id))),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AvatarCircle(name: clinic.doctorName, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clinic.doctorName, style: AppText.poppins(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  Text(
                    [clinic.qualification, clinic.speciality].where((x) => x.isNotEmpty).join(' • '),
                    style: AppText.inter(fontSize: 12.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [clinic.name, clinic.place].where((x) => x.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppChip(
                        label: clinic.waiting == 0 ? 'No wait' : '${clinic.waiting} waiting • ~${clinic.waitMinutes} min',
                        icon: Icons.hourglass_bottom_rounded,
                        color: clinic.waiting == 0 ? AppColors.successSoft : AppColors.warningSoft,
                        textColor: clinic.waiting == 0 ? AppColors.success : AppColors.warning,
                        fontSize: 11,
                      ),
                      if (clinic.distanceKm != null)
                        AppChip(label: '${clinic.distanceKm} km', icon: Icons.near_me_rounded, color: AppColors.chipBlue, textColor: AppColors.textPrimary, fontSize: 11),
                      AppChip(label: '₹${clinic.fee}', color: AppColors.mint, textColor: AppColors.primaryDark, fontSize: 11),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Doctor and clinic information, live wait, slots for a booking request,
/// the clinic's blogs and camps.
class ClinicDetailScreen extends StatefulWidget {
  const ClinicDetailScreen({super.key, required this.clinicId});

  final int clinicId;

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  Map<String, dynamic>? _data;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _day => '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    try {
      final d = await api.get('/api/explore/clinics/${widget.clinicId}', query: {'date': _day}) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _book(Map<String, dynamic> slot) async {
    final member = await pickMember(context, title: 'Who is the visit for?');
    if (member == null || !mounted) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${member.name} • ${dayDate(_date)} • ${slot['time']}'),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send request')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final mins = slot['startMin'] as int;
    final start = DateTime(_date.year, _date.month, _date.day, mins ~/ 60, mins % 60);
    final messenger = ScaffoldMessenger.of(context);
    if (await runAction(context, () => patientStore.requestAppointment(widget.clinicId, start, member, reason.text.trim()))) {
      messenger.showSnackBar(const SnackBar(content: Text('Request sent. You will be notified when the clinic confirms.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final clinic = d?['clinic'] as Map<String, dynamic>?;
    final doctor = d?['doctor'] as Map<String, dynamic>?;
    final slots = (d?['slots'] as List?) ?? const [];
    final posts = ((d?['posts'] as List?) ?? const []).map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
    final camps = ((d?['camps'] as List?) ?? const []).map((e) => Camp.fromJson(e as Map<String, dynamic>)).toList();

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(clinic?['name'] as String? ?? 'Clinic', style: AppText.inter(fontSize: 16))),
      body: d == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : ErrorBanner(message: _error!, onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AvatarCircle(name: doctor!['name'] as String, size: 60),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doctor['name'] as String, style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                                  Text(
                                    [doctor['qualification'], doctor['speciality']].where((x) => (x as String).isNotEmpty).join(' • '),
                                    style: AppText.inter(fontSize: 13, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${doctor['experienceYears']} yrs experience • ₹${doctor['fee']} fee',
                                    style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if ((doctor['bio'] as String).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(doctor['bio'] as String, style: AppText.inter(fontSize: 13.5, height: 1.45)),
                        ],
                        if ((doctor['languages'] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Speaks: ${doctor['languages']}', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                        const Divider(height: 22),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [clinic!['address'], clinic['city']].where((x) => (x as String).isNotEmpty).join(', ').ifEmptyText('Address not added'),
                                style: AppText.inter(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if ((clinic['phone'] as String).isNotEmpty)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: clinic['phone'] as String)),
                                  icon: const Icon(Icons.call_rounded, size: 18),
                                  label: const Text('Call'),
                                ),
                              ),
                            if ((clinic['phone'] as String).isNotEmpty) const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => launchUrl(
                                  Uri.parse(clinic['lat'] != null
                                      ? 'https://www.google.com/maps/search/?api=1&query=${clinic['lat']},${clinic['lng']}'
                                      : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${clinic['name']} ${clinic['address']} ${clinic['city']}')}'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.directions_rounded, size: 18),
                                label: const Text('Directions'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (d['waiting'] as int) == 0 ? AppColors.successSoft : AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_bottom_rounded, color: (d['waiting'] as int) == 0 ? AppColors.success : AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (d['waiting'] as int) == 0
                                ? 'No one waiting right now'
                                : '${d['waiting']} waiting • about ${d['waitMinutes']} min',
                            style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Book a visit'),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Builder(builder: (context) {
                            final day = DateTime.now().add(Duration(days: i));
                            final selected = day.day == _date.day && day.month == _date.month;
                            return FilterPill(
                              label: i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : dayDate(day)),
                              selected: selected,
                              onTap: () {
                                setState(() => _date = day);
                                _load();
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (slots.isEmpty)
                    Text('No open slots on this day.', style: AppText.inter(fontSize: 13, color: AppColors.textMuted))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in slots.cast<Map<String, dynamic>>())
                          ActionChip(
                            label: Text(s['time'] as String),
                            onPressed: (s['available'] as int) > 0 ? () => _book(s) : null,
                            backgroundColor: (s['available'] as int) > 0 ? Colors.white : AppColors.chipBlue,
                            side: const BorderSide(color: Color(0xFFDDE3F5)),
                          ),
                      ],
                    ),
                  if (camps.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const SectionLabel('Health camps'),
                    for (final c in camps) Padding(padding: const EdgeInsets.only(bottom: 10), child: CampCard(camp: c)),
                  ],
                  if (posts.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const SectionLabel('Blogs'),
                    for (final p in posts) Padding(padding: const EdgeInsets.only(bottom: 12), child: BlogCard(post: p)),
                  ],
                ],
              ),
            ),
    );
  }
}

extension on String {
  String ifEmptyText(String other) => isEmpty ? other : this;
}
