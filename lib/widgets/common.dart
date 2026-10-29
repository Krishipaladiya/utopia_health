import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../data/doctor_store.dart';
import '../screens/doctor_profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../services/api_client.dart';

/// Top bar used on Home, Rx, Patients and Finance.
/// Small round logo, then clinic name + doctor name with full room to read.
/// Tapping the avatar opens the doctor profile.
class ClinicHeader extends StatelessWidget {
  const ClinicHeader({
    super.key,
    this.section,
    this.showBell = true,
    this.showBadge = false,
  });

  /// Optional screen label shown before the doctor name, e.g. "Patients".
  final String? section;
  final bool showBell;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: doctorProfile,
      builder: (context, _) {
        final doctor = doctorProfile.headerLine;
        final subtitle = section == null ? doctor : '$section • $doctor';

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const _RoundLogo(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            doctorProfile.clinic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mintSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.mint),
                            ),
                            child: Text(
                              'Utopia',
                              style: AppText.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (showBell) ...[
                ListenableBuilder(
                  listenable: notifications,
                  builder: (context, _) => IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: Badge(
                      isLabelVisible: notifications.unread > 0,
                      label: Text('${notifications.unread}'),
                      backgroundColor: AppColors.primaryGreen,
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              DoctorAvatar(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DoctorProfileScreen(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundLogo extends StatelessWidget {
  const _RoundLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mint, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/app_icon_dark.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({super.key, this.initials, this.size = 40, this.onTap});

  final String? initials;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: doctorProfile,
      builder: (context, _) => Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.mint, width: 2),
            ),
            child: Text(
              initials ?? doctorProfile.initials,
              style: AppText.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.color = AppColors.chipBlue,
    this.textColor = AppColors.textMuted,
    this.icon,
    this.fontSize = 12,
    this.bold = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.inter(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green tinted pill used for remedy names.
class RemedyChip extends StatelessWidget {
  const RemedyChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label,
      icon: Icons.medication_outlined,
      color: AppColors.mint,
      textColor: AppColors.primaryDark,
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppText.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.name,
    this.size = 48,
    this.icon,
  });

  final String name;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    final skip = {'Master', 'Mr.', 'Mrs.', 'Dr.'};
    final useful = words.where((w) => !skip.contains(w)).take(2).toList();
    final initials = useful.map((w) => w[0]).join();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: icon != null ? const Color(0xFFDDE3FA) : AppColors.mint,
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.46, color: const Color(0xFF3F4A8A))
          : Text(
              initials,
              style: AppText.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
                fontSize: size * 0.34,
              ),
            ),
    );
  }
}

/// White rounded card with the soft shadow used across the design.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: radius,
        border: borderColor == null
            ? Border.all(color: const Color(0x0F000000))
            : Border.all(color: borderColor!, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2B6B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Pill used for filters (selected = dark teal with white text).
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primaryDark : AppColors.chipBlue,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppText.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs an API action and shows a friendly message if it fails.
Future<bool> runAction(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(e.friendly)));
    return false;
  }
}

/// Shown when the server cannot be reached.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
