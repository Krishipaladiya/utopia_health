import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import 'auth_flow.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

/// After a login: offer a 4-digit PIN so next time is one step. Skippable.
Future<void> offerPinSetup(BuildContext context) async {
  if (!await auth.shouldOfferPin() || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _SetPinSheet(),
  );
}

/// Login finished: offer a PIN, then open the right home screen.
Future<void> finishLogin(BuildContext context, {bool newlyRegistered = false}) async {
  TextInput.finishAutofillContext();
  await offerPinSetup(context);
  if (context.mounted) enterApp(context, newlyRegistered: newlyRegistered);
}

class _SetPinSheet extends StatefulWidget {
  const _SetPinSheet();

  @override
  State<_SetPinSheet> createState() => _SetPinSheetState();
}

class _SetPinSheetState extends State<_SetPinSheet> {
  String _first = '';
  String _pin = '';
  String? _error;
  bool _saving = false;

  Future<void> _onDigit(String d) async {
    if (_saving) return;
    setState(() {
      _error = null;
      if (d == '<') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 4) {
        _pin += d;
      }
    });
    if (_pin.length < 4) return;
    if (_first.isEmpty) {
      setState(() {
        _first = _pin;
        _pin = '';
      });
      return;
    }
    if (_pin != _first) {
      HapticFeedback.mediumImpact();
      setState(() {
        _error = 'PINs did not match. Try again.';
        _first = '';
        _pin = '';
      });
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await auth.setPin(_pin);
      navigator.pop();
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.friendly;
        _first = '';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primaryDark),
          const SizedBox(height: 8),
          Text(
            _first.isEmpty ? 'Set a 4-digit PIN' : 'Enter the PIN again',
            style: AppText.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Next time, open the app with this PIN. It works only on this phone.',
            textAlign: TextAlign.center,
            style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          PinDots(length: _pin.length, error: _error != null),
          SizedBox(
            height: 26,
            child: Center(
              child: Text(_error ?? '', style: AppText.inter(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          ),
          PinPad(onKey: _onDigit),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        ],
      ),
    );
  }
}

/// App start with a saved PIN: pick the account (if several) and enter the PIN.
class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key, required this.pins});

  final List<SavedPin> pins;

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  late SavedPin _selected = widget.pins.first;
  String _pin = '';
  String? _error;
  bool _busy = false;

  String _roleLabel(String role) => switch (role) {
        'doctor' => 'Doctor',
        'reception' => 'Front desk',
        'clinic' => 'Partner clinic',
        'lab' => 'Laboratory',
        _ => 'Patient',
      };

  Future<void> _onKey(String d) async {
    if (_busy) return;
    setState(() {
      _error = null;
      if (d == '<') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 4) {
        _pin += d;
      }
    });
    if (_pin.length < 4) return;
    setState(() => _busy = true);
    try {
      await auth.pinLogin(_selected, _pin);
      if (mounted) enterApp(context);
    } on ApiException catch (e) {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _error = e.friendly;
      });
      if (e.code == 'pin_not_set' || e.code == 'not_registered') _otherWay();
    }
  }

  void _otherWay() {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        children: [
          AuthHeading(title: 'Welcome back', subtitle: '${_selected.name} • ${_roleLabel(_selected.role)}'),
          if (widget.pins.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final p in widget.pins)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: p.pinId == _selected.pinId,
                    onSelected: (_) => setState(() {
                      _selected = p;
                      _pin = '';
                      _error = null;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          PinDots(length: _pin.length, error: _error != null),
          SizedBox(
            height: 30,
            child: Center(
              child: Text(_error ?? (_busy ? 'Checking...' : 'Enter your 4-digit PIN'),
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _error != null ? AppColors.danger : AppColors.textMuted,
                  )),
            ),
          ),
          PinPad(onKey: _onKey),
          const SizedBox(height: 6),
          TextButton(onPressed: _otherWay, child: const Text('Log in another way')),
        ],
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.error = false});

  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? (error ? AppColors.danger : AppColors.primaryDark) : Colors.transparent,
              border: Border.all(color: error ? AppColors.danger : AppColors.primaryDark, width: 2),
            ),
          ),
      ],
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onKey});

  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {IconData? icon}) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 72,
            height: 60,
            child: Material(
              color: icon == null ? AppColors.chipBlueSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onKey(label),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: AppColors.textMuted, semanticLabel: 'Delete')
                      : Text(label, style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        );
    return Column(
      children: [
        for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const SizedBox(width: 84), key('0'), key('<', icon: Icons.backspace_outlined)],
        ),
      ],
    );
  }
}
