import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/expense_entry_presenter.dart';
import '../../domain/providers.dart';

class EntryTelemetryPill extends ConsumerWidget {
  const EntryTelemetryPill({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(args));
    final segments = EntryTelemetryPresenter.build(
      state.draft,
      batteryCapacityKwh: state.defaults.batteryCapacityKwh,
    );
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final semantics = segments
        .map((item) => '${item.prefix}${item.value}${item.suffix}')
        .join('，');
    return Semantics(
      label: '能耗预估：$semantics',
      excludeSemantics: true,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_rounded,
                size: 13,
                color: palette.primaryText,
              ),
              const SizedBox(width: 4),
              Text(
                '能耗预估',
                style: AppTypography.labelMd.copyWith(
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(width: 10),
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '·',
                      style: AppTypography.bodySm.copyWith(
                        color: palette.outlineVariant,
                      ),
                    ),
                  ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: segments[i].prefix),
                      TextSpan(
                        text: segments[i].value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: segments[i].suffix),
                    ],
                  ),
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 11,
                    color: palette.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
