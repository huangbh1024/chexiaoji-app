import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/expense_detail_models.dart';
import '../../domain/expense_detail_presenter.dart';
import '../expense_detail_style.dart';

/// 摘要卡：分类图标、标题、分类副标题、金额、状态与时间。
class DetailHeroCard extends StatelessWidget {
  const DetailHeroCard({super.key, required this.detail});

  final ExpenseDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final category = detail.record.category;
    final status = detail.status;

    return Semantics(
      container: true,
      label:
          '${detail.categoryLabel}，${detail.titleText}，'
          '${detail.heroAmountText}，${detail.statusLabel}，${detail.timeText}',
      child: AppCard(
        radius: ExpenseDetailStyle.cardRadius,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ExpenseDetailStyle.cardRadius),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(ExpenseDetailStyle.heroPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    _HeroIcon(category: category),
                    const SizedBox(height: 12),
                    Text(
                      detail.titleText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm.copyWith(
                        color: palette.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail.categoryCaption,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSm.copyWith(
                        color: palette.outline,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HeroAmount(detail: detail),
                      const SizedBox(height: 8),
                      _StatusLine(detail: detail, status: status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.category});

  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final icon = category.icon;
    final onColor = color.computeLuminance() > 0.55
        ? const Color(0xFF004A33)
        : Colors.white;
    return Container(
      width: ExpenseDetailStyle.heroIconSize,
      height: ExpenseDetailStyle.heroIconSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.white, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(ExpenseDetailStyle.iconRadius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 30, color: onColor),
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({required this.detail});

  final ExpenseDetail detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final negative = detail.record.amountCents < 0;
    final zero = detail.record.amountCents == 0;
    final prefix = negative
        ? '+¥'
        : zero
        ? '¥'
        : '-¥';
    final amount = formatYuanDetail(detail.record.amountCents.abs()).substring(1);
    final color = negative ? palette.primaryText : palette.onSurface;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            prefix,
            style: AppTypography.headlineLg.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            amount,
            style: AppTypography.displayHero.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.detail, required this.status});

  final ExpenseDetail detail;
  final ExpenseStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = AppTypography.labelMd.copyWith(
      color: palette.outline,
      fontWeight: FontWeight.w600,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Icon(status.icon, size: 15, color: status.color(palette)),
        Text(detail.statusLabel, style: style),
        Text('·', style: style.copyWith(color: palette.outlineVariant)),
        Text(detail.timeText, style: style),
      ],
    );
  }
}
