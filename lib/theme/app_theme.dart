// ============================================================================
// APP THEME
// Light, soft-sky look: pale-blue page background, white cards with soft
// shadows, large radii, pill buttons and pastel-gradient feature cards.
//
// Every screen reaches for AppColors / AppStyle instead of hand-rolling a
// colour or radius, so a future look change is this one file. main.dart
// re-exports it, so `import '../main.dart' show AppColors` keeps working.
//
// Contrast: text colours are chosen to meet WCAG AA (4.5:1) on both `bg` and
// `surface`; white text on `primary` / `success` / `danger` fills and on the
// card gradients below is >= 3.3:1 and used for bold, large labels.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Surfaces
  static const bg = Color(0xFFEAF4FF); // page background (soft sky)
  static const bgTop = Color(0xFFD9ECFF); // top of the Home gradient
  static const surface = Color(0xFFFFFFFF); // cards, sheets, inputs
  static const tint = Color(0xFFE4EFFC); // chips, tracks, subtle fills/borders
  static const lineStrong = Color(0xFFC3D6EE); // stronger borders, dividers

  // Text (darkest to faintest)
  static const textPrimary = Color(0xFF12294A);
  static const textSoft = Color(0xFF1E3558);
  static const textBody = Color(0xFF334A6B);
  static const textMuted = Color(0xFF566C8F);
  static const textFaint = Color(0xFF6B82A5); // hints, disabled, quiet icons

  // Brand blue
  static const primary = Color(0xFF1C73D0); // buttons, selected states
  static const primaryDark = Color(0xFF1760B3);
  static const primaryText = Color(0xFF1966C2); // blue text / icons on light

  // Success (correct answers, streak, "done")
  static const success = Color(0xFF0A8576);
  static const successText = Color(0xFF077568);

  // Danger (wrong answers, destructive, strike-through)
  static const danger = Color(0xFFD6384E);
  static const dangerText = Color(0xFFC42A46);

  // Warning / amber. `warning` is for fills and icons; use `warningText` for
  // any amber *text* (amber on white is too faint to read).
  static const warning = Color(0xFFD67A00);
  static const warningText = Color(0xFFA85A07);

  // Feature-card gradients (start -> end), all >= 3.3:1 against white text.
  static const gradBlue = [Color(0xFF3590EA), Color(0xFF1C73D0)];
  static const gradOrange = [Color(0xFFD87906), Color(0xFFC46400)];
  static const gradPurple = [Color(0xFF7A83CB), Color(0xFF656EB8)];
  static const gradTeal = [Color(0xFF13A090), Color(0xFF0A8576)];
  static const gradCyan = [Color(0xFF1A98D0), Color(0xFF0E84BE)];
  static const gradRose = [Color(0xFFE85F83), Color(0xFFD64370)];
}

class AppStyle {
  static const double radiusXl = 28.0; // floating nav, hero banners
  static const double radiusLg = 24.0; // cards
  static const double radiusMd = 16.0; // buttons, tiles, option rows
  static const double radiusSm = 12.0; // small pills, badges
  static const double radiusPill = 30.0; // fully-rounded buttons and chips
  static const double pagePadding = 20.0;
  static const double sectionGap = 28.0;

  /// Soft blue-grey drop shadow used on white cards.
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x1A1F5FA8),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

/// Bold title + optional muted subtitle, used to open every major section.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded icon in a soft tinted square. [size] is the outer box; the icon
/// itself is ~55% of it.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.lineStrong,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Roboto',
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.tint,
        disabledForegroundColor: AppColors.textFaint,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusPill),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.lineStrong),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusPill),
        ),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: const Color(0x261F5FA8),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.radiusLg),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.tint,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : AppColors.lineStrong,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textFaint),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.radiusMd),
        borderSide: const BorderSide(color: AppColors.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppStyle.radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.radiusMd),
      ),
    ),
    dividerColor: AppColors.tint,
  );
}
