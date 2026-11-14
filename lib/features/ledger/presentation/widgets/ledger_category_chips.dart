import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/providers.dart';

/// 分类筛选：全部类型 + 7 类开支。
class LedgerCategoryChips extends ConsumerWidget {
  const LedgerCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(ledgerFilterProvider);
    final options = <ExpenseCategory?>[null, ...ExpenseCategory.values];

    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = options[index];
          return _CategoryChip(
            category: category,
            selected: filter.category == category,
            onTap: () => ref
                .read(ledgerFilterProvider.notifier)
                .selectCategory(category),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ExpenseCategory? category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = category == null ? '全部类型' : category!.filterLabel;
    final foreground = selected ? palette.primaryText : palette.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.18)
              : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? palette.primary.withValues(alpha: 0.35)
                : palette.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category != null) ...[
              Icon(
                category!.icon,
                size: 13,
                color: selected ? palette.primaryText : category!.color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
