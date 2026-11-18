import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_theme.dart';
import '../../data/network_stores.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../content/content_views.dart';

/// Web address of the check-in page that a clinic's QR opens.
String checkInLink(String code) => '${ApiConfig.portalUrl}#/checkin/$code';

/// Doctor: clinic details shown to patients (address, location, about) and
/// the QR code patients scan at reception to get a token.
class ClinicQrScreen extends StatefulWidget {
  const ClinicQrScreen({super.key});

  @override
  State<ClinicQrScreen> createState() => _ClinicQrScreenState();
}

class _ClinicQrScreenState extends State<ClinicQrScreen> {
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _about = TextEditingController();
  double? _lat;
  double? _lng;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await teamStore.loadClinic();
      final c = teamStore.clinicInfo!;
      final phone = (c['phone'] as String?) ?? '';
      _phone.text = phone.length > 10 ? phone.substring(phone.length - 10) : phone;
      _address.text = (c['address'] as String?) ?? '';
      _city.text = (c['city'] as String?) ?? '';
      _about.text = (c['about'] as String?) ?? '';
      _lat = (c['lat'] as num?)?.toDouble();
      _lng = (c['lng'] as num?)?.toDouble();
      if (mounted) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _locate() async {
    final p = await currentPosition();
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allow location to pin the clinic on the map')));
      return;
    }
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await runAction(context, () => teamStore.saveClinic({
          'phone': _phone.text,
          'address': _address.text.trim(),
          'city': _city.text.trim(),
          'about': _about.text.trim(),
          'lat': _lat,
          'lng': _lng,
        }));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) messenger.showSnackBar(const SnackBar(content: Text('Clinic details saved')));
  }

  @override
  Widget build(BuildContext context) {
    final code = teamStore.clinicInfo?['publicCode'] as String?;
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Clinic QR & details', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
          if (code != null)
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('Scan to get a token', style: AppText.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Print this and keep it at reception. Patients scan with any phone camera, enter their number and get a token.',
                    textAlign: TextAlign.center,
                    style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  QrImageView(
                    data: checkInLink(code),
                    size: 220,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.primaryDark),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF14201C)),
                  ),
                  const SizedBox(height: 8),
                  Text('Clinic code: $code', style: AppText.poppins(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: checkInLink(code)));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in link copied')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy check-in link'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const SectionLabel('Shown to patients'),
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: const InputDecoration(labelText: 'Clinic phone', prefixText: '+91 '),
                ),
                TextField(
                  controller: _address,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.fullStreetAddress],
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressCity],
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                TextField(
                  controller: _about,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'About the clinic'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.place_rounded, color: _lat == null ? AppColors.textFaint : AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lat == null ? 'Not on the map yet' : 'Pinned at ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                        style: AppText.inter(fontSize: 13),
                      ),
                    ),
                    TextButton(onPressed: _locate, child: const Text("I'm at the clinic")),
                  ],
                ),
                Text(
                  'Pin the location so nearby patients find you in Explore.',
                  style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: Text(_saving ? 'Saving...' : 'Save details'),
            ),
          ),
        ],
      ),
    );
  }
}
