import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Yacare brand wordmark with decorative flourish. Pacifico is bundled in pubspec.yaml.
class BarBeerWordmark extends StatelessWidget {
  final double fontSize;
  final Color? beerColor;

  const BarBeerWordmark({super.key, this.fontSize = 24, this.beerColor});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Yacare',
        style: TextStyle(
          fontFamily: 'Pacifico',
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: 1.15,
          color: AppColors.brand,
        ),
      ),
      const SizedBox(height: 4),
      CustomPaint(
        size: Size(fontSize * 2.8, fontSize * 0.35),
        painter: _FlourishPainter(),
      ),
    ],
  );
}

class _FlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFA855F7),
          const Color(0xFFF97316),
          const Color(0xFFF59E0B),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.2, 0,
        size.width * 0.4, 0,
        size.width * 0.5, size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.6, size.height,
        size.width * 0.8, size.height,
        size.width, size.height * 0.3,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
