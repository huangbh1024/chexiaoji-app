import 'package:material_ui/material_ui.dart';

/// Plus Jakarta Sans 负责数字与拉丁字符，中文回退到系统字体。
class AppTypography {
  const AppTypography._();

  static const _fallback = <String>[
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Noto Sans SC',
    'sans-serif',
  ];

  static const displayHero = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 38,
    height: 44 / 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.14,
  );

  static const headlineLg = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.52,
  );

  static const headlineMd = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const headlineSm = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
  );

  static const bodyLg = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
  );

  static const bodyMd = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  static const bodySm = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w400,
  );

  static const labelLg = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
  );

  static const labelMd = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
  );

  static const labelSm = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const metric = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 24,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const metricSub = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontFamilyFallback: _fallback,
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  static TextTheme textTheme(Color color) {
    TextStyle withColor(TextStyle style) => style.copyWith(color: color);

    return TextTheme(
      displayLarge: withColor(displayHero),
      displayMedium: withColor(headlineLg),
      headlineLarge: withColor(headlineLg),
      headlineMedium: withColor(headlineMd),
      headlineSmall: withColor(headlineSm),
      titleLarge: withColor(headlineSm),
      titleMedium: withColor(bodyLg),
      titleSmall: withColor(bodyMd),
      bodyLarge: withColor(bodyLg),
      bodyMedium: withColor(bodyMd),
      bodySmall: withColor(bodySm),
      labelLarge: withColor(labelLg),
      labelMedium: withColor(labelMd),
      labelSmall: withColor(labelSm),
    );
  }
}
