import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/ledger_models.dart';

/// 汇总卡的日开销迷你柱状图：一天一根，今天高亮、峰值日加环。
class LedgerDailyBars extends StatelessWidget {
  const LedgerDailyBars({
    super.key,
    required this.points,
    this.peakDate,
    this.today,
  });

  final List<LedgerDailyPoint> points;
  final DateTime? peakDate;
  final DateTime? today;

  static const _baseHeight = 8.0;
  static const _maxHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reference = today ?? DateTime.now();
    final peak = points.fold<int>(
      0,
      (value, point) => math.max(value, point.amountCents),
    );

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final point in points)
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 6,
              height: _height(point.amountCents, peak),
              decoration: BoxDecoration(
                color: _color(point, reference, palette),
                borderRadius: BorderRadius.circular(999),
                border: _border(point, reference, palette),
              ),
            ),
        ],
      ),
    );
  }

  double _height(int amountCents, int peakCents) {
    if (peakCents <= 0) {
      return _baseHeight;
    }
    final ratio = (amountCents / peakCents).clamp(0.0, 1.0);
    return (_baseHeight + (_maxHeight - _baseHeight) * ratio).roundToDouble();
  }

  Color _color(
    LedgerDailyPoint point,
    DateTime today,
    AppPalette palette,
  ) {
    if (isSameDay(point.date, today)) {
      return palette.primary;
    }
    if (peakDate != null && isSameDay(point.date, peakDate!)) {
      return palette.secondary;
    }
    final category = point.dominantCategory;
    if (category == null || point.amountCents <= 0) {
      return palette.surfaceContainer;
    }
    return category.color.withValues(alpha: 0.45);
  }

  Border? _border(
    LedgerDailyPoint point,
    DateTime today,
    AppPalette palette,
  ) {
    if (isSameDay(point.date, today)) {
      return Border.all(
        color: palette.primary.withValues(alpha: 0.35),
        width: 2,
      );
    }
    if (peakDate != null && isSameDay(point.date, peakDate!)) {
      return Border.all(
        color: palette.secondary.withValues(alpha: 0.35),
        width: 2,
      );
    }
    return null;
  }
}
