import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Three layered green waves from the brand splash design.
/// [start] is where the top wave begins, as a fraction of the height.
class WaveBackground extends StatelessWidget {
  const WaveBackground({super.key, this.start = 0.70});

  final double start;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WavePainter(start));
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.start);

  final double start;

  @override
  void paint(Canvas canvas, Size size) {
    void wave(double top, Color color, double amplitude) {
      final path = Path()..moveTo(0, size.height);
      path.lineTo(0, top);
      path.cubicTo(
        size.width * 0.25,
        top - amplitude,
        size.width * 0.55,
        top + amplitude,
        size.width,
        top - amplitude * 0.4,
      );
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    final h = size.height;
    final amp = h * 0.06;
    wave(h * start, AppColors.mint, amp);
    wave(h * (start + 0.10), const Color(0xFF86E8B4), amp * 0.85);
    wave(h * (start + 0.18), AppColors.primaryGreen, amp * 0.65);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.start != start;
}
