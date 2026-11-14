import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/ledger_models.dart';
import '../../domain/ledger_presenter.dart';

/// 单条流水记录卡。
class LedgerRecordCard extends StatelessWidget {
  const LedgerRecordCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  final LedgerRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Semantics(
      button: true,
      container: true,
      label: _semanticsLabel(),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: Border.all(
            color: palette.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _CategoryIcon(category: record.category),
                  const SizedBox(width: 12),
                  Expanded(child: _RecordInfo(record: record)),
                  const SizedBox(width: 8),
                  _RecordAmount(record: record),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel() {
    final date = '${record.occurredAt.month}月${record.occurredAt.day}日';
    final amount = record.amountCents.abs() / 100;
    final vehicle = record.vehicleShortName;
    return '$date，${record.category.label}，${record.title}，'
        '${amount.toStringAsFixed(2)}元，$vehicle';
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: category.softColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(category.icon, size: 24, color: category.color),
    );
  }
}

class _RecordInfo extends StatelessWidget {
  const _RecordInfo({required this.record});

  final LedgerRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final subtitle = record.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                record.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLg.copyWith(
                  color: palette.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (record.badgeText != null) ...[
              const SizedBox(width: 6),
              _Badge(record: record),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(color: palette.outline),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.record});

  final LedgerRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isVehicle = record.badgeKind == LedgerBadgeKind.vehicle;
    final background = isVehicle
        ? record.powertrain.color.withValues(alpha: 0.16)
        : palette.surfaceContainer;
    final foreground = isVehicle
        ? record.powertrain.badgeTextColor(palette)
        : palette.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        record.badgeText!,
        style: AppTypography.labelSm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecordAmount extends StatelessWidget {
  const _RecordAmount({required this.record});

  final LedgerRecord record;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pill = record.unitPricePillText;
    final trailing = record.trailingText;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            record.expenseText,
            maxLines: 1,
            style: AppTypography.headlineSm.copyWith(
              color: palette.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (pill != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: record.category.softColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pill,
                style: AppTypography.labelSm.copyWith(
                  color: record.category.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else if (trailing != null) ...[
            const SizedBox(height: 2),
            Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
          ],
        ],
      ),
    );
  }
}
