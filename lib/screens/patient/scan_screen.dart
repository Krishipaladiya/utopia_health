import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../services/api_client.dart';
import 'family_screen.dart';

/// Clinic code from a scanned QR: the check-in link ends with /checkin/CODE,
/// or the QR holds just the code.
String? clinicCodeFrom(String raw) {
  final m = RegExp(r'checkin/([A-Za-z0-9]{4,12})').firstMatch(raw);
  if (m != null) return m.group(1)!.toUpperCase();
  final t = raw.trim();
  return RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(t) ? t.toUpperCase() : null;
}

Future<void> openScan(BuildContext context) async {
  final code = kIsWeb
      ? await _typeCode(context)
      : await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
  if (code == null || !context.mounted) return;
  final member = await pickMember(context, title: 'Token for whom?');
  if (member == null || !context.mounted) return;
  try {
    final r = await patientStore.checkIn(code, member);
    if (context.mounted) await showTokenDialog(context, r);
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.code == 'clinic_not_found' ? 'This QR is not a Utopia Health clinic.' : e.friendly)),
      );
    }
  }
}

Future<String?> _typeCode(BuildContext context) async {
  final c = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clinic code'),
      content: TextField(
        controller: c,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'Code printed under the QR'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Get token')),
      ],
    ),
  );
  return code == null ? null : clinicCodeFrom(code);
}

/// "Your token is #7": big animated number, people ahead, expected wait.
Future<void> showTokenDialog(BuildContext context, Map<String, dynamic> r) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Token',
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (context, a, _, _) {
      final scale = CurvedAnimation(parent: a, curve: Curves.elasticOut);
      return Opacity(
        opacity: a.value.clamp(0, 1),
        child: Center(
          child: ScaleTransition(
            scale: scale,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 46),
                    const SizedBox(height: 8),
                    Text('You are in the queue', style: AppText.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
                    Text('${r['memberName']} • ${r['clinicName']}', textAlign: TextAlign.center, style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(height: 14),
                    Text('TOKEN', style: AppText.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
                    Text('#${r['tokenNumber']}', style: AppText.poppins(fontSize: 56, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    Text(
                      (r['ahead'] as int) == 0 ? "You're next" : '${r['ahead']} ahead • about ${r['waitMinutes']} min',
                      style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text('We will notify you when it is your turn.', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  late final _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _line.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = clinicCodeFrom(b.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan clinic QR'),
        actions: [
          IconButton(onPressed: _controller.toggleTorch, icon: const Icon(Icons.flash_on_rounded)),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _line,
                    builder: (context, _) => Positioned(
                      top: 12 + 222 * _line.value,
                      left: 14,
                      right: 14,
                      child: Container(height: 3, color: const Color(0xFF86F0D6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 60,
            child: Text(
              'Point at the QR code at the clinic reception to get your token.',
              textAlign: TextAlign.center,
              style: AppText.inter(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
