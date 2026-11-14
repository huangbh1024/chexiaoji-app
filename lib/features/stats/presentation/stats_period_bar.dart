import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/providers.dart';
import '../domain/stats_period.dart';

class StatsPeriodBar extends ConsumerWidget {
  const StatsPeriodBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final filter = ref.watch(statsFilterProvider);
    final range = resolveStatsRange(filter.period, filter.anchor);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              boxShadow: tokens.cardShadow,
            ),
            child: Row(
              children: [
                for (final period in StatsPeriod.values)
                  Expanded(
                    child: _PeriodChip(
                      label: period.chipLabel,
                      selected: filter.period == period,
                      onTap: () => _selectPeriod(ref, period),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _DateRangePill(
          label: range.label,
          enabled: filter.period != StatsPeriod.all,
          onTap: () =>
              _showAnchorSheet(context, ref, filter.period, filter.anchor),
        ),
      ],
    );
  }

  void _selectPeriod(WidgetRef ref, StatsPeriod period) {
    ref.read(statsFilterProvider.notifier).selectPeriod(period);
    ref.read(statsTrendRangeProvider.notifier).applyPeriodDefault(period);
  }

  Future<void> _showAnchorSheet(
    BuildContext context,
    WidgetRef ref,
    StatsPeriod period,
    DateTime anchor,
  ) async {
    if (period == StatsPeriod.all) {
      return;
    }
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnchorSheet(period: period, anchor: anchor),
    );
    if (selected == null) {
      return;
    }
    ref.read(statsFilterProvider.notifier).selectAnchor(selected);
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMd.copyWith(
              color: selected ? palette.surface : palette.outline,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRangePill extends StatelessWidget {
  const _DateRangePill({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: InkWell(
        key: const Key('stats-date-pill'),
        onTap: enabled ? onTap : null,
        customBorder: const StadiumBorder(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            boxShadow: tokens.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 15,
                color: enabled ? palette.primaryText : palette.outline,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 124),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: palette.onSurface,
                    fontWeight: FontWeight.w600,
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

class _AnchorSheet extends StatelessWidget {
  const _AnchorSheet({required this.period, required this.anchor});

  final StatsPeriod period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final options = _options(now);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    _title,
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: palette.outline),
                  ),
                ],
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected =
                        option.anchor.year == anchor.year &&
                        option.anchor.month == anchor.month &&
                        (period != StatsPeriod.week ||
                            option.anchor.day == anchor.day);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        option.label,
                        style: AppTypography.bodyMd.copyWith(
                          color: palette.onSurface,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: palette.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(option.anchor),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title => switch (period) {
    StatsPeriod.week => '选择周',
    StatsPeriod.month => '选择月份',
    StatsPeriod.halfYear => '选择半年',
    StatsPeriod.year => '选择年份',
    StatsPeriod.all => '全部',
  };

  List<({String label, DateTime anchor})> _options(DateTime now) {
    switch (period) {
      case StatsPeriod.week:
        final today = DateTime(now.year, now.month, now.day);
        final thisMonday = DateTime(
          today.year,
          today.month,
          today.day - (today.weekday - 1),
        );
        return [
          for (var index = 0; index < 12; index++)
            () {
              final monday = DateTime(
                thisMonday.year,
                thisMonday.month,
                thisMonday.day - index * 7,
              );
              final sunday = DateTime(
                monday.year,
                monday.month,
                monday.day + 6,
              );
              return (
                label:
                    '${monday.month}/${monday.day}–${sunday.month}/${sunday.day}',
                anchor: monday,
              );
            }(),
        ];
      case StatsPeriod.month:
        return [
          for (var index = 0; index < 24; index++)
            () {
              final month = DateTime(now.year, now.month - index);
              return (
                label: '${month.year}年${month.month}月',
                anchor: DateTime(month.year, month.month, 1),
              );
            }(),
        ];
      case StatsPeriod.halfYear:
        return [
          for (var index = 0; index < 8; index++)
            () {
              final base = DateTime(now.year, now.month - index * 6);
              final firstHalf = base.month <= 6;
              final year = base.year;
              return (
                label: '$year${firstHalf ? '上半年' : '下半年'}',
                anchor: DateTime(year, firstHalf ? 1 : 7, 1),
              );
            }(),
        ];
      case StatsPeriod.year:
        return [
          for (var index = 0; index < 6; index++)
            () {
              final year = now.year - index;
              return (label: '$year年', anchor: DateTime(year, 1, 1));
            }(),
        ];
      case StatsPeriod.all:
        return const [];
    }
  }
}
