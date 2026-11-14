import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

abstract final class ExpenseEntryStyle {
  static const cardRadius = 28.0;
  static const sectionGap = 20.0;
  static const fieldRadius = 16.0;
  static const buttonHeight = 52.0;

  static List<BoxShadow> cardShadow(BuildContext context) =>
      context.tokens.cardShadow;

  static BoxDecoration cardDecoration(BuildContext context) {
    final palette = context.palette;
    return BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: palette.cardBorder),
      boxShadow: context.tokens.cardShadow,
    );
  }
}
