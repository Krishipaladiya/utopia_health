import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/appointments_store.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String dayLabel(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';

/// Book a slot for a patient. Pass [patient] to skip the patient step.
Future<void> showBookingSheet(BuildContext context, {Patient? patient, DateTime? date}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xCC1B2740),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _BookingSheet(patient: patient, date: date),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({this.patient, this.date});

  final Patient? patient;
  final DateTime? date;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _search = TextEditingController();
  late Patient? _patient = widget.patient;
  late DateTime _date = _dateOnly(widget.date ?? DateTime.now());
  int? _slotMin;

  List<SlotInfo> _slots = [];
  bool _loadingSlots = true;
  String? _slotError;
  bool _booking = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotError = null;
      _slotMin = null;
    });
    try {
      final list = await appointments.availableSlots(_date);
      if (!mounted) return;
      setState(() {
        _slots = list;
        _loadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _slotError = e.friendly;
        _loadingSlots = false;
      });
    }
  }

  DateTime _slotTime(int min) =>
      DateTime(_date.year, _date.month, _date.day, min ~/ 60, min % 60);

  bool _isPast(SlotInfo s) =>
      _slotTime(s.startMin).add(Duration(minutes: slotConfig.slotMinutes)).isBefore(DateTime.now());

  bool _isBookable(SlotInfo s) => s.available > 0 && !_isPast(s);

  Future<void> _book() async {
    final patient = _patient;
    final min = _slotMin;
    if (patient == null || min == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final when = _slotTime(min);
    setState(() => _booking = true);
    try {
      await appointments.book(patient, when);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${patient.name} booked for ${formatMinutes(min)}, ${dayLabel(when)}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _booking = false);
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
      if (e.code == 'slot_full') _loadSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canBook = _patient != null && _slotMin != null && !_booking;

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD5DAE4),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Book appointment',
                  style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              _label('Patient'),
              if (_patient != null) _selectedPatient() else _patientPicker(),
              _label('Date'),
              _dateStrip(),
              _label('Time'),
              _slotArea(),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3)),
            ],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: canBook ? _book : null,
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                disabledBackgroundColor: const Color(0xFFB9D5CF),
                disabledForegroundColor: Colors.white,
              ),
              icon: const Icon(Icons.event_available_outlined, size: 20),
              label: Text(
                _booking
                    ? 'Booking...'
                    : _slotMin == null
                        ? 'Pick a time'
                        : 'Book ${formatMinutes(_slotMin!)} • ${dayLabel(_date)}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: AppText.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
      );

  Widget _selectedPatient() {
    final p = _patient!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        children: [
          AvatarCircle(name: p.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  '${p.age}y / ${p.genderShort} • ${p.phone}',
                  style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (widget.patient == null)
            TextButton(
              onPressed: () => setState(() => _patient = null),
              child: const Text('Change'),
            ),
        ],
      ),
    );
  }

  Widget _patientPicker() {
    final q = _search.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final matches = clinic.patients
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.id.toLowerCase().contains(q) ||
            (digits.length >= 3 && p.phone.replaceAll(RegExp(r'\D'), '').contains(digits)))
        .take(6)
        .toList();

    return Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: AppText.inter(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search name, phone or ID',
            hintStyle: AppText.inter(fontSize: 15, color: AppColors.textFaint),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.chipBlueSoft,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'No patient found. Add the patient from the Patients tab first.',
              style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        for (final p in matches)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: AvatarCircle(name: p.name, size: 40),
            title: Text(p.name, style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${p.age}y / ${p.genderShort} • ${p.phone}',
              style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
            ),
            onTap: () => setState(() => _patient = p),
          ),
      ],
    );
  }

  Widget _dateStrip() {
    final start = _dateOnly(DateTime.now());
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = start.add(Duration(days: i));
          final selected = d == _date;
          return GestureDetector(
            onTap: () {
              setState(() => _date = d);
              _loadSlots();
            },
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : AppColors.chipBlueSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Today' : _weekdays[d.weekday - 1],
                    style: AppText.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: AppText.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _monthNames[d.month - 1],
                    style: AppText.inter(
                      fontSize: 11,
                      color: selected ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slotArea() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_slotError != null) {
      return ErrorBanner(message: _slotError!, onRetry: _loadSlots);
    }
    if (_slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.chipBlueSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_busy_outlined, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No slots on ${dayLabel(_date)}. This day is off in your slot setup.',
                style: AppText.inter(fontSize: 13.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    Widget group(String title, Iterable<SlotInfo> slots) {
      if (slots.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              title,
              style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in slots) _slotChip(s)],
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        group('Morning', _slots.where((s) => s.startMin < 12 * 60)),
        group('Afternoon', _slots.where((s) => s.startMin >= 12 * 60 && s.startMin < 17 * 60)),
        group('Evening', _slots.where((s) => s.startMin >= 17 * 60)),
      ],
    );
  }

  Widget _slotChip(SlotInfo s) {
    final selected = _slotMin == s.startMin;
    final bookable = _isBookable(s);
    final fg = selected
        ? Colors.white
        : bookable
            ? AppColors.textPrimary
            : AppColors.textFaint;

    return Material(
      color: selected
          ? AppColors.primaryDark
          : bookable
              ? AppColors.mint
              : const Color(0xFFF0F2F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: bookable ? () => setState(() => _slotMin = s.startMin) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMinutes(s.startMin),
                style: AppText.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ).copyWith(decoration: bookable ? null : TextDecoration.lineThrough),
              ),
              if (s.capacity > 1 && bookable)
                Text(
                  '${s.available} left',
                  style: AppText.inter(
                    fontSize: 10.5,
                    color: selected ? Colors.white70 : AppColors.primaryDark,
                  ),
                )
              else if (s.available == 0)
                Text('Full', style: AppText.inter(fontSize: 10.5, color: AppColors.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}
