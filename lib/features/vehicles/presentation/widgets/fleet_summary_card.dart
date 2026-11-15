import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import '../vehicle_management_style.dart';

class FleetSummaryCard extends StatelessWidget {
  const FleetSummaryCard({super.key, required this.summary});

  final FleetSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final health = VehiclePresenter.healthLabel(summary);
    final hasIssues = summary.pendingIssueCount > 0;
    final composition = VehiclePresenter.powertrainComposition(
      summary.powertrainCounts,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroMid, palette.heroEnd],
        ),
        borderRadius: BorderRadius.circular(VehicleManagementStyle.cardRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: tokens.heroShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VehicleManagementStyle.cardRadius),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              bottom: -48,
              child: IgnorePointer(
                child: Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -32,
              top: -32,
              child: IgnorePointer(
                child: Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(
                    color: palette.tertiary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(VehicleManagementStyle.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.garage_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '车库资产总览',
                          style: AppTypography.labelLg.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      if (health.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasIssues
                                ? palette.secondary.withValues(alpha: 0.42)
                                : Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(
                              tokens.radiusPill,
                            ),
                          ),
                          child: Text(
                            health,
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: '累计行驶里程',
                          value: _MileageValue(km: summary.totalOdometerKm),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          label: '本月车队总开销',
                          value: _MoneyValue(cents: summary.monthSpendCents),
                        ),
                      ),
                    ],
                  ),
                  if (composition.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 12),
                    _CompositionRow(counts: summary.powertrainCounts),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VehicleManagementStyle.innerRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }
}

class _MileageValue extends StatelessWidget {
  const _MileageValue({required this.km});

  final int km;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatCount(km),
            style: AppTypography.displayHero.copyWith(
              fontSize: 28,
              height: 32 / 28,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 3),
            child: Text(
              'km',
              style: AppTypography.labelMd.copyWith(
                fontSize: 12,
                height: 16 / 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyValue extends StatelessWidget {
  const _MoneyValue({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final text = formatYuanCompact(cents);
    final number = text.startsWith('¥') ? text.substring(1) : text;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '¥',
              style: AppTypography.headlineSm.copyWith(
                height: 22 / 16,
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            number,
            style: AppTypography.displayHero.copyWith(
              fontSize: 28,
              height: 32 / 28,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({required this.counts});

  final Map<PowertrainType, int> counts;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final type in const [
      PowertrainType.ev,
      PowertrainType.phev,
      PowertrainType.hev,
      PowertrainType.ice,
    ]) {
      final count = counts[type] ?? 0;
      if (count == 0) {
        continue;
      }
      if (items.isNotEmpty) {
        items.add(
          Text(
            '|',
            style: AppTypography.labelSm.copyWith(
              color: Colors.white.withValues(alpha: 0.30),
            ),
          ),
        );
      }
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _dotColor(type),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_label(type)} $count 辆',
              style: AppTypography.labelMd.copyWith(
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }

  String _label(PowertrainType type) => switch (type) {
    PowertrainType.ev => '纯电',
    PowertrainType.phev => '插混',
    PowertrainType.hev => '油混',
    PowertrainType.ice => '燃油',
  };

  Color _dotColor(PowertrainType type) => switch (type) {
    PowertrainType.ev => const Color(0xFF63FCC0),
    PowertrainType.phev => const Color(0xFF89CEFF),
    PowertrainType.hev => const Color(0xFFFFB77A),
    PowertrainType.ice => const Color(0xFFFFDCC2),
  };
}
