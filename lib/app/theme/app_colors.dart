import 'package:material_ui/material_ui.dart';

/// 设计稿语义色。深色值目前为推导值，等正式深色稿接入后替换。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.primaryText,
    required this.secondary,
    required this.secondaryText,
    required this.tertiary,
    required this.violet,
    required this.pink,
    required this.error,
    required this.errorSoft,
    required this.heroStart,
    required this.heroMid,
    required this.heroEnd,
    required this.navBar,
    required this.cardBorder,
    required this.shadow,
    required this.glassBorder,
    required this.disabled,
  });

  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color primaryText;
  final Color secondary;
  final Color secondaryText;
  final Color tertiary;
  final Color violet;
  final Color pink;
  final Color error;
  final Color errorSoft;
  final Color heroStart;
  final Color heroMid;
  final Color heroEnd;
  final Color navBar;
  final Color cardBorder;
  final Color shadow;
  final Color glassBorder;
  final Color disabled;

  static const light = AppPalette(
    background: Color(0xFFF8F9FF),
    surface: Colors.white,
    surfaceContainer: Color(0xFFEFF4FF),
    onSurface: Color(0xFF0B1C30),
    onSurfaceVariant: Color(0xFF64748B),
    outline: Color(0xFF6C7A72),
    outlineVariant: Color(0xFFDCE6F2),
    primary: Color(0xFF00C48C),
    primaryText: Color(0xFF006C4B),
    secondary: Color(0xFFFC9D41),
    secondaryText: Color(0xFF8F4E00),
    tertiary: Color(0xFF0EA5E9),
    violet: Color(0xFF8B5CF6),
    pink: Color(0xFFEC4899),
    error: Color(0xFFBA1A1A),
    errorSoft: Color(0xFFFEE2E2),
    heroStart: Color(0xFF00C48C),
    heroMid: Color(0xFF05B380),
    heroEnd: Color(0xFF0A8C66),
    navBar: Color(0xFFFDFEFF),
    cardBorder: Color(0xFFFFFFFF),
    shadow: Color(0xFF0F172A),
    glassBorder: Color(0xFFFFFFFF),
    disabled: Color(0xFFB8C4D6),
  );

  /// TODO(dark-design): 正式深色设计稿提供后替换为设计 token。
  static const dark = AppPalette(
    background: Color(0xFF0B1C30),
    surface: Color(0xFF14263D),
    surfaceContainer: Color(0xFF1C314C),
    onSurface: Color(0xFFEAF1FF),
    onSurfaceVariant: Color(0xFFA8BCD4),
    outline: Color(0xFF7E8FA6),
    outlineVariant: Color(0xFF2A405C),
    primary: Color(0xFF00C48C),
    primaryText: Color(0xFF3FDFA5),
    secondary: Color(0xFFFC9D41),
    secondaryText: Color(0xFFFFB77A),
    tertiary: Color(0xFF36B6FB),
    violet: Color(0xFFA78BFA),
    pink: Color(0xFFF472B6),
    error: Color(0xFFFFB4AB),
    errorSoft: Color(0xFF4A1D1D),
    heroStart: Color(0xFF00C48C),
    heroMid: Color(0xFF05B380),
    heroEnd: Color(0xFF0A8C66),
    navBar: Color(0xFF14263D),
    cardBorder: Color(0x14FFFFFF),
    shadow: Color(0xFF000000),
    glassBorder: Color(0x1AFFFFFF),
    disabled: Color(0xFF4B5F77),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      pink: Color.lerp(pink, other.pink, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroMid: Color.lerp(heroMid, other.heroMid, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}

/// 分类与动力类型的固定语义色，不随明暗主题变化（深色稿接入后可再调）。
class AppColors {
  const AppColors._();

  static const charging = Color(0xFF00C48C);
  static const fuel = Color(0xFFFC9D41);
  static const maintenance = Color(0xFFEAB308);
  static const parking = Color(0xFF0EA5E9);
  static const toll = Color(0xFF8B5CF6);
  static const carWash = Color(0xFFEC4899);
  static const other = Color(0xFF94A3B8);

  static const ev = Color(0xFF00C48C);
  static const hev = Color(0xFFFC9D41);
  static const phev = Color(0xFF0EA5E9);
  static const ice = Color(0xFFF59E0B);

  static const rise = Color(0xFFF43F5E);
  static const sparkleWhite = Color(0xFFFFFFFF);
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
