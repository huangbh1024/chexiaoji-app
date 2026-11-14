import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/expense_entry_presenter.dart';
import '../../domain/providers.dart';

class EntryCategoryChips extends ConsumerWidget {
  const EntryCategoryChips({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final category = ref.watch(
      expenseEntryControllerProvider(args)
          .select((state) => state.draft.category),
    );
    const order = [
      ExpenseCategory.charging,
      ExpenseCategory.fuel,
      ExpenseCategory.parking,
      ExpenseCategory.toll,
      ExpenseCategory.maintenance,
      ExpenseCategory.carWash,
      ExpenseCategory.other,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                '支出分类',
                style: AppTypography.labelMd.copyWith(color: palette.outline),
              ),
              const Spacer(),
              Text(
                category.entryHint,
                style: AppTypography.labelSm.copyWith(
                  color: palette.primaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: order.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = order[index];
              return _CategoryChip(
                category: item,
                selected: item == category,
                onTap: () => ref
                    .read(expenseEntryControllerProvider(args).notifier)
                    .selectCategory(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? Colors.white : palette.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '${category.entryLabel}，支出分类',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 14),
            decoration: BoxDecoration(
              color: selected ? palette.primary : palette.surface,
              borderRadius: BorderRadius.circular(999),
              border: selected ? null : Border.all(color: palette.cardBorder),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : context.tokens.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category.icon,
                  size: 18,
                  color: selected ? Colors.white : category.color,
                ),
                const SizedBox(width: 6),
                Text(
                  category.entryLabel,
                  style: AppTypography.labelLg.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
