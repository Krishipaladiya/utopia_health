import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';

/// Add a patient fee (income) or log a clinic spend (expense).
Future<void> showMoneySheet(BuildContext context, {required bool isFee}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0xCC1B2740),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _MoneySheet(isFee: isFee),
  );
}

class _MoneySheet extends StatefulWidget {
  const _MoneySheet({required this.isFee});

  final bool isFee;

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  final _who = TextEditingController();
  final _amount = TextEditingController();
  late String _mode = widget.isFee ? 'UPI (GPay)' : 'Cash';

  List<String> get _modes => widget.isFee
      ? const ['UPI (GPay)', 'PhonePe', 'Cash', 'Card']
      : const ['Cash', 'UPI', 'Bank IMPS'];

  List<int> get _quick => widget.isFee ? const [300, 500, 800] : const [500, 1000, 3000];

  @override
  void dispose() {
    _who.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_amount.text) ?? 0;
  bool get _valid => _who.text.trim().length >= 2 && _value > 0;

  bool _saving = false;

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final value = _value;
    setState(() => _saving = true);
    try {
      if (widget.isFee) {
        await clinic.addFee(patientName: _who.text.trim(), amount: value, mode: _mode);
      } else {
        await clinic.addSpend(title: _who.text.trim(), amount: value, mode: _mode);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(widget.isFee ? '₹$value fee added' : '₹$value spend logged')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isFee = widget.isFee;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DAE4),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isFee ? 'Add patient fee' : 'Log clinic spend',
                    style: AppText.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            _label(isFee ? 'Patient' : 'What was it for?'),
            TextField(
              controller: _who,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: AppText.inter(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: _decoration(
                isFee ? 'e.g. Rajesh Kumar' : 'e.g. Clinic rent',
              ),
            ),
            if (isFee) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in clinic.patients.take(4))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(p.name),
                          onPressed: () => setState(() => _who.text = p.name),
                          backgroundColor: AppColors.chipBlue,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          labelStyle: AppText.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            _label('Amount'),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: _decoration('0').copyWith(
                prefixText: '₹ ',
                prefixStyle: AppText.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final q in _quick)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('₹$q'),
                      onPressed: () => setState(() => _amount.text = '$q'),
                      backgroundColor: AppColors.mint,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: AppText.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
              ],
            ),
            _label('Paid by'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in _modes)
                    FilterPill(
                      label: m,
                      selected: _mode == m,
                      onTap: () => setState(() => _mode = m),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _valid && !_saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  disabledBackgroundColor: const Color(0xFFB9D5CF),
                  disabledForegroundColor: Colors.white,
                ),
                icon: Icon(
                  isFee ? Icons.add_circle_outline : Icons.receipt_long_outlined,
                  size: 20,
                ),
                label: Text(isFee ? 'Add fee' : 'Log spend'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          text,
          style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );

  InputDecoration _decoration(String hint) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.inter(fontSize: 15, color: AppColors.textFaint),
      filled: true,
      fillColor: AppColors.chipBlueSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: b(const Color(0xFFDDE3F5)),
      focusedBorder: b(AppColors.primaryDark, 1.6),
    );
  }
}
