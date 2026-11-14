import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static const _fontFamilyFallback = <String>[
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Noto Sans SC',
    'sans-serif',
  ];

  static ThemeData light() => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
    tokens: AppTokens.light,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    tokens: AppTokens.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required AppTokens tokens,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: Colors.white,
          secondary: palette.secondary,
          onSecondary: Colors.white,
          surface: palette.surface,
          onSurface: palette.onSurface,
          error: palette.error,
          onError: Colors.white,
          outline: palette.outline,
          outlineVariant: palette.outlineVariant,
          surfaceContainerLow: palette.surfaceContainer,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: AppTypography.textTheme(palette.onSurface),
      extensions: <ThemeExtension<dynamic>>[palette, tokens],
    );
  }
}
