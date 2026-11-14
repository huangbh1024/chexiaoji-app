import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../domain/expense_entry_math.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/expense_entry_validation.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';

class EntryMileageCard extends ConsumerStatefulWidget {
  const EntryMileageCard({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  ConsumerState<EntryMileageCard> createState() => _EntryMileageCardState();
}

class _EntryMileageCardState extends ConsumerState<EntryMileageCard> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final odometer = ref
        .read(expenseEntryControllerProvider(widget.args))
        .draft
        .odometerKm;
    _controller = TextEditingController(text: odometer?.toString() ?? '');
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _sync(
          ref
              .read(expenseEntryControllerProvider(widget.args))
              .draft
              .odometerKm,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sync(int? value) {
    final text = value?.toString() ?? '';
    if (_controller.text == text) {
      return;
    }
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(widget.args));
    final visible = categoryUsesOdometer(state.draft.category);
    ref.listen<int?>(
      expenseEntryControllerProvider(widget.args)
          .select((value) => value.draft.odometerKm),
      (previous, next) {
        if (!_focusNode.hasFocus) {
          _sync(next);
        }
      },
    );

    if (!visible && !_expanded) {
      return AppCard(
        radius: ExpenseEntryStyle.cardRadius,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: InkWell(
          onTap: () => setState(() => _expanded = true),
          child: Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: palette.tertiary),
              const SizedBox(width: 8),
              Text(
                '补充里程（选填）',
                style: AppTypography.bodyMd.copyWith(
                  color: palette.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(Icons.expand_more_rounded, size: 18, color: palette.outline),
            ],
          ),
        ),
      );
    }

    final last = state.draft.lastOdometerKm;
    final delta = state.draft.distanceKm;
    final validation = state.validation;
    final odometerError = validation.isField(EntryField.odometer)
        ? validation.message
        : null;

    return AppCard(
      radius: ExpenseEntryStyle.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '里程仪表读数',
                style: AppTypography.bodyLg.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '距上次自增核算',
                style: AppTypography.labelSm.copyWith(
                  color: palette.outline,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '上次记录读数',
                      style: AppTypography.labelSm.copyWith(
                        color: palette.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (state.isLoadingBaseline)
                      const SkeletonBox(width: 88, height: 16)
                    else if (last == null)
                      Text(
                        '首次记录',
                        style: AppTypography.bodyMd.copyWith(
                          color: palette.outline,
                        ),
                      )
                    else
                      Text(
                        formatKm(last),
                        style: AppTypography.bodyMd.copyWith(
                          color: palette.outline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: palette.outlineVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '本次仪表里程',
                      style: AppTypography.labelSm.copyWith(
                        color: palette.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: TextField(
                            key: const Key('entry-odometer'),
                            controller: _controller,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            maxLength: 7,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: AppTypography.bodyMd.copyWith(
                              color: palette.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration.collapsed(
                              hintText: '未填写',
                              hintStyle: AppTypography.bodyMd.copyWith(
                                color: palette.outlineVariant,
                              ),
                            ).copyWith(counterText: ''),
                            onChanged: (text) {
                              final value = int.tryParse(text);
                              ref
                                  .read(
                                    expenseEntryControllerProvider(widget.args)
                                        .notifier,
                                  )
                                  .setOdometerKm(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'km',
                          style: AppTypography.labelSm.copyWith(
                            color: palette.outline,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '区间实际行驶里程',
                  style: AppTypography.bodySm.copyWith(
                    color: palette.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  delta == null
                      ? '—'
                      : delta < 0
                      ? '不能小于上次读数'
                      : formatOdometerDelta(delta),
                  style: AppTypography.bodyMd.copyWith(
                    color: delta != null && delta < 0
                        ? palette.error
                        : palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (odometerError != null) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                odometerError,
                style: AppTypography.bodySm.copyWith(color: palette.error),
              ),
            ),
          ],
          if (state.baselineError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '上次读数加载失败，本次不校验里程',
                    style: AppTypography.bodySm.copyWith(color: palette.error),
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(
                        expenseEntryControllerProvider(widget.args).notifier,
                      )
                      .retryBaseline(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ],
          if (!visible) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => setState(() => _expanded = false),
              child: const Text('收起'),
            ),
          ],
        ],
      ),
    );
  }
}
