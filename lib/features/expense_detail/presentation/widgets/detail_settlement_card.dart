import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/expense_detail_models.dart';
import '../../domain/expense_detail_presenter.dart';
import '../expense_detail_style.dart';

/// 结算明细卡：分类、支付渠道、交易时间、实付金额。
class DetailSettlementCard extends StatelessWidget {
  const DetailSettlementCard({
    super.key,
    required this.detail,
    this.isSyncing = false,
  });

  final ExpenseDetail detail;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      radius: ExpenseDetailStyle.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: palette.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                '结算明细',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '电子记账',
                style: AppTypography.bodySm.copyWith(color: palette.outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          _SettlementRow(
            label: '开销类别',
            value: Text(
              detail.record.category.label,
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _SettlementRow(
            label: '支付渠道',
            value: _PaymentValue(
              payment: detail.payment,
              isSyncing: isSyncing,
            ),
          ),
          _SettlementRow(
            label: '交易时间',
            value: Text(
              detail.timeText,
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            showDivider: false,
          ),
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                detail.settledLabel,
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                detail.settledAmountText,
                style: AppTypography.headlineLg.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final Widget value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodyMd.copyWith(color: palette.outline),
              ),
              const SizedBox(width: 16),
              Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

class _PaymentValue extends StatelessWidget {
  const _PaymentValue({required this.payment, this.isSyncing = false});

  final ExpensePayment? payment;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final payment = this.payment;
    if (payment == null && isSyncing) {
      return const SkeletonBox(width: 88, height: 12, radius: 6);
    }
    if (payment == null || payment.label.trim().isEmpty) {
      return Text(
        '未记录',
        textAlign: TextAlign.right,
        style: AppTypography.bodyMd.copyWith(color: palette.onSurface),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: payment.channel.color(palette),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            payment.label,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd.copyWith(
              color: palette.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
