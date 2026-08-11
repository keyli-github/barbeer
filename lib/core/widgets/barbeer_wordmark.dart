import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The joined BarBeer brand treatment. Pacifico is bundled in pubspec.yaml.
class BarBeerWordmark extends StatelessWidget {
  final double fontSize;
  final Color beerColor;

  const BarBeerWordmark({
    super.key,
    this.fontSize = 24,
    this.beerColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: TextStyle(
        fontFamily: 'Pacifico',
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.15,
      ),
      children: [
        const TextSpan(
          text: 'Bar',
          style: TextStyle(color: AppColors.brand),
        ),
        TextSpan(
          text: 'Beer',
          style: TextStyle(color: beerColor),
        ),
      ],
    ),
  );
}
