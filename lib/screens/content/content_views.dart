import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../models/network.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

/// The phone's location, or null when the person says no.
Future<Position?> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
    );
  } catch (_) {
    return null;
  }
}

String mediaUrl(int id) => api.url('/api/media/$id');

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String dayDate(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
String clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

(IconData, Color) campStyle(String kind) => switch (kind) {
      'Blood donation' => (Icons.bloodtype_rounded, const Color(0xFFD32F2F)),
      'Full body checkup' => (Icons.monitor_heart_rounded, const Color(0xFF00897B)),
      'Eye checkup' => (Icons.visibility_rounded, const Color(0xFF3949AB)),
      'Vaccination' => (Icons.vaccines_rounded, const Color(0xFF7B1FA2)),
      'Dental checkup' => (Icons.mood_rounded, const Color(0xFFEF6C00)),
      _ => (Icons.health_and_safety_rounded, AppColors.primaryDark),
    };

class CampCard extends StatelessWidget {
  const CampCard({super.key, required this.camp, this.width});

  final Camp camp;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = campStyle(camp.kind);
    return SizedBox(
      width: width,
      child: SoftCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampDetailScreen(camp: camp))),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    camp.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _line(Icons.event_rounded, '${dayDate(camp.startsAt)} • ${clock(camp.startsAt)}'),
            _line(Icons.place_outlined, [camp.venue, camp.city].where((x) => x.isNotEmpty).join(', ')),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                if (camp.endsAt.isBefore(DateTime.now()))
                  const AppChip(label: 'Ended', color: AppColors.chipBlue, textColor: AppColors.textMuted, fontSize: 11, bold: true),
                AppChip(label: camp.fee == 0 ? 'Free' : '₹${camp.fee}', color: AppColors.successSoft, textColor: AppColors.success, fontSize: 11, bold: true),
                if (camp.distanceKm != null)
                  AppChip(label: '${camp.distanceKm} km', color: AppColors.chipBlue, textColor: AppColors.textPrimary, fontSize: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
            ),
          ],
        ),
      );
}

class CampDetailScreen extends StatelessWidget {
  const CampDetailScreen({super.key, required this.camp});

  final Camp camp;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = campStyle(camp.kind);
    final mapsUrl = camp.lat != null
        ? 'https://www.google.com/maps/search/?api=1&query=${camp.lat},${camp.lng}'
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${camp.venue}, ${camp.city}')}';
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                ),
                child: Center(child: Icon(icon, size: 80, color: Colors.white.withValues(alpha: 0.9))),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                AppChip(label: camp.kind, color: color.withValues(alpha: 0.12), textColor: color, bold: true),
                const SizedBox(height: 8),
                Text(camp.title, style: AppText.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                Text('By ${camp.clinicName}', style: AppText.inter(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 14),
                SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _row(Icons.event_rounded, 'When', '${dayDate(camp.startsAt)}\n${clock(camp.startsAt)} – ${clock(camp.endsAt)}'),
                      _row(Icons.place_outlined, 'Where', [camp.venue, camp.city].where((x) => x.isNotEmpty).join(', ')),
                      _row(Icons.payments_outlined, 'Fee', camp.fee == 0 ? 'Free' : '₹${camp.fee}'),
                      if (camp.distanceKm != null) _row(Icons.near_me_outlined, 'Distance', '${camp.distanceKm} km away'),
                    ],
                  ),
                ),
                if (camp.details.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(camp.details, style: AppText.inter(fontSize: 14.5, height: 1.5)),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => launchUrl(Uri.parse(mapsUrl), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.directions_rounded),
                        label: const Text('Directions'),
                      ),
                    ),
                    if (camp.contactPhone.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: camp.contactPhone)),
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Call'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryDark),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: Text(label, style: AppText.inter(fontSize: 13, color: AppColors.textMuted))),
            Expanded(child: Text(value, style: AppText.inter(fontSize: 14, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class BlogCard extends StatelessWidget {
  const BlogCard({super.key, required this.post, this.width, this.onTap});

  final BlogPost post;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cover = post.cover;
    final hasVideo = post.videoUrl.isNotEmpty || post.media.any((m) => m.isVideo);
    return SizedBox(
      width: width,
      child: SoftCard(
        onTap: onTap ?? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BlogDetailScreen(post: post))),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover == null
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFD9F2E8), Color(0xFFE6EBFA)]),
                            ),
                            child: const Icon(Icons.article_outlined, size: 40, color: AppColors.primaryDark),
                          )
                        : Image.network(
                            mediaUrl(cover.id),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.chipBlue,
                              child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                            ),
                          ),
                    if (hasVideo)
                      const Center(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xAA000000),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    if (!post.published)
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: AppChip(label: 'Draft', color: AppColors.warningSoft, textColor: AppColors.warning, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${post.doctorName} • ${relativeTime(post.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlogDetailScreen extends StatelessWidget {
  const BlogDetailScreen({super.key, required this.post});

  final BlogPost post;

  @override
  Widget build(BuildContext context) {
    final images = post.media.where((m) => !m.isVideo).toList();
    final videos = post.media.where((m) => m.isVideo).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(post.clinicName, style: AppText.inter(fontSize: 15))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(post.title, style: AppText.poppins(fontSize: 23, fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 8),
          Row(
            children: [
              AvatarCircle(name: post.doctorName, size: 32),
              const SizedBox(width: 8),
              Text('${post.doctorName} • ${dayDate(post.date)}', style: AppText.inter(fontSize: 12.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          for (final img in images)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  mediaUrl(img.id),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          for (final v in videos)
            _VideoTile(label: v.name.isEmpty ? 'Watch video' : v.name, url: mediaUrl(v.id)),
          if (post.videoUrl.isNotEmpty) _VideoTile(label: 'Watch video', url: post.videoUrl),
          const SizedBox(height: 6),
          Text(post.body, style: AppText.inter(fontSize: 15.5, height: 1.65)),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF14201C),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: SizedBox(
            height: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 54),
                const SizedBox(height: 6),
                Text(label, style: AppText.inter(fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
