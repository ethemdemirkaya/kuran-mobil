import 'package:flutter/material.dart';

class AppColors {
  static const green = Color(0xFF1F5E54);
  static const greenDark = Color(0xFF143F38);
  static const gold = Color(0xFFB8893B);
  static const cream = Color(0xFFFBF7EF);
  static const paper = Color(0xFFFFFDF8);
  static const night = Color(0xFF0F1513);
  static const nightCard = Color(0xFF18211E);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: brightness,
    primary: dark ? const Color(0xFF7CC4B4) : AppColors.green,
    secondary: AppColors.gold,
    surface: dark ? AppColors.night : AppColors.cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? AppColors.nightCard : AppColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 18, height: 1.5),
      bodyMedium: TextStyle(fontSize: 16, height: 1.4),
    ),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
  );
}

/// Ayet numarası rozeti.
class VerseBadge extends StatelessWidget {
  const VerseBadge(this.number, {super.key, this.active = false, this.size = 40});

  final int number;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.785,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                color: active ? AppColors.gold : Colors.transparent,
                border: Border.all(color: active ? AppColors.gold : scheme.primary, width: 1.6),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              border: Border.all(
                  color: active ? AppColors.gold : scheme.primary.withValues(alpha: 0.5),
                  width: 1.2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Text(
            '$number',
            style: TextStyle(
              fontSize: size * (number > 99 ? 0.28 : 0.34),
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
