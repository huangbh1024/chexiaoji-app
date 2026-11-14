import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 打开月份选择弹层，返回用户选中的月份（当月 1 日）。
Future<DateTime?> showLedgerMonthPicker(
  BuildContext context,
  DateTime current,
) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _LedgerMonthPickerSheet(current: current),
  );
}

class _LedgerMonthPickerSheet extends StatefulWidget {
  const _LedgerMonthPickerSheet({required this.current});

  final DateTime current;

  @override
  State<_LedgerMonthPickerSheet> createState() =>
      _LedgerMonthPickerSheetState();
}

class _LedgerMonthPickerSheetState extends State<_LedgerMonthPickerSheet> {
  late int _year = widget.current.year;
  late int _month = widget.current.month;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final years = <int>[
      for (var offset = 0; offset < 3; offset++) now.year - offset,
    ];
    if (!years.contains(_year)) {
      years.add(_year);
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选择月份',
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              InkResponse(
                onTap: () => Navigator.of(context).pop(),
                radius: 20,
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: palette.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final year in years) ...[
                  _YearChip(
                    year: year,
                    selected: year == _year,
                    onTap: () => setState(() => _year = year),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final itemWidth = (constraints.maxWidth - gap * 3) / 4;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var month = 1; month <= 12; month++)
                    _MonthCell(
                      width: itemWidth,
                      month: month,
                      selected: month == _month,
                      disabled: _year == now.year && month > now.month,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(DateTime(_year, month)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(DateTime(_year, _month)),
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.year,
    required this.selected,
    required this.onTap,
  });

  final int year;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? palette.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? palette.primary.withValues(alpha: 0.4)
                : palette.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          '$year年',
          style: AppTypography.labelMd.copyWith(
            color: selected ? palette.primaryText : palette.outline,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.width,
    required this.month,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final double width;
  final int month;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: width,
      height: 40,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? palette.primary.withValues(alpha: 0.16)
                : palette.surfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              '$month月',
              style: AppTypography.labelLg.copyWith(
                color: disabled
                    ? palette.outline.withValues(alpha: 0.5)
                    : selected
                    ? palette.primaryText
                    : palette.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
