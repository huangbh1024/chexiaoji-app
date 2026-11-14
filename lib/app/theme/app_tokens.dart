import 'package:material_ui/material_ui.dart';

/// 间距、圆角、阴影等布局 token。深色值随主题切换。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.pagePadding,
    required this.gutter,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.radiusCard,
    required this.radiusChip,
    required this.radiusPill,
    required this.radiusNav,
    required this.cardShadow,
    required this.heroShadow,
    required this.selectedShadow,
    required this.navShadow,
    required this.headerHeight,
    required this.navHeight,
    required this.contentBottomPadding,
  });

  final double pagePadding;
  final double gutter;
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double radiusCard;
  final double radiusChip;
  final double radiusPill;
  final double radiusNav;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> heroShadow;
  final List<BoxShadow> selectedShadow;
  final List<BoxShadow> navShadow;
  final double headerHeight;
  final double navHeight;
  final double contentBottomPadding;

  static const light = AppTokens(
    pagePadding: 16,
    gutter: 12,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 20,
    spaceXl: 28,
    radiusCard: 16,
    radiusChip: 6,
    radiusPill: 999,
    radiusNav: 48,
    cardShadow: [
      BoxShadow(
        color: Color(0x0A0F172A),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Color(0x050F172A),
        blurRadius: 6,
        offset: Offset(0, 2),
        spreadRadius: -1,
      ),
    ],
    heroShadow: [
      BoxShadow(
        color: Color(0x3800C48C),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
    selectedShadow: [
      BoxShadow(
        color: Color(0x4000C48C),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
    ],
    navShadow: [
      BoxShadow(
        color: Color(0x0D0B1C30),
        blurRadius: 20,
        offset: Offset(0, -4),
      ),
    ],
    headerHeight: 64,
    navHeight: 64,
    contentBottomPadding: 112,
  );

  static const dark = AppTokens(
    pagePadding: 16,
    gutter: 12,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 20,
    spaceXl: 28,
    radiusCard: 16,
    radiusChip: 6,
    radiusPill: 999,
    radiusNav: 48,
    cardShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
    ],
    heroShadow: [
      BoxShadow(
        color: Color(0x4000C48C),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
    selectedShadow: [
      BoxShadow(
        color: Color(0x4D00C48C),
        blurRadius: 24,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
    ],
    navShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 20,
        offset: Offset(0, -4),
      ),
    ],
    headerHeight: 64,
    navHeight: 64,
    contentBottomPadding: 112,
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) {
      return this;
    }
    List<BoxShadow> shadow(List<BoxShadow> a, List<BoxShadow> b) {
      if (a.length != b.length) {
        return t < 0.5 ? a : b;
      }
      return [
        for (var i = 0; i < a.length; i++)
          BoxShadow.lerp(a[i], b[i], t) ?? a[i],
      ];
    }

    return AppTokens(
      pagePadding: _lerpDouble(pagePadding, other.pagePadding, t),
      gutter: _lerpDouble(gutter, other.gutter, t),
      spaceXs: _lerpDouble(spaceXs, other.spaceXs, t),
      spaceSm: _lerpDouble(spaceSm, other.spaceSm, t),
      spaceMd: _lerpDouble(spaceMd, other.spaceMd, t),
      spaceLg: _lerpDouble(spaceLg, other.spaceLg, t),
      spaceXl: _lerpDouble(spaceXl, other.spaceXl, t),
      radiusCard: _lerpDouble(radiusCard, other.radiusCard, t),
      radiusChip: _lerpDouble(radiusChip, other.radiusChip, t),
      radiusPill: _lerpDouble(radiusPill, other.radiusPill, t),
      radiusNav: _lerpDouble(radiusNav, other.radiusNav, t),
      cardShadow: shadow(cardShadow, other.cardShadow),
      heroShadow: shadow(heroShadow, other.heroShadow),
      selectedShadow: shadow(selectedShadow, other.selectedShadow),
      navShadow: shadow(navShadow, other.navShadow),
      headerHeight: _lerpDouble(headerHeight, other.headerHeight, t),
      navHeight: _lerpDouble(navHeight, other.navHeight, t),
      contentBottomPadding: _lerpDouble(
        contentBottomPadding,
        other.contentBottomPadding,
        t,
      ),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
