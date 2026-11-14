import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/expense_entry_detail.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/expense_entry_presenter.dart';
import '../../domain/expense_entry_validation.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';

class EntryParamsCard extends ConsumerWidget {
  const EntryParamsCard({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final header = paramsHeader(state.draft);
    final child = switch (state.draft.detail) {
      ChargingDetail _ => _ChargingParams(args: args),
      FuelDetail _ => _FuelParams(args: args),
      ParkingDetail _ => _ParkingParams(args: args),
      TollDetail _ => _TollParams(args: args),
      MaintenanceDetail _ => _MaintenanceParams(args: args),
      CarWashDetail _ => _CarWashParams(args: args),
      InsuranceDetail _ => _InsuranceParams(args: args),
      EmptyEntryDetail _ => const SizedBox.shrink(),
    };
    return AppCard(
      radius: ExpenseEntryStyle.cardRadius,
      padding: const EdgeInsets.all(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey(state.draft.category),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: state.draft.category.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    header.title,
                    style: AppTypography.bodyLg.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w700,
                      color: context.palette.onSurface,
                    ),
                  ),
                ),
                Text(
                  header.hint,
                  style: AppTypography.labelSm.copyWith(
                    color: context.palette.outline,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: context.palette.surfaceContainer),
            const SizedBox(height: 12),
            child,
            if (_paramsValidation(state.validation) != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _paramsValidation(state.validation)!,
                  style: AppTypography.bodySm.copyWith(
                    color: context.palette.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _paramsValidation(EntryValidation validation) {
    const fields = {
      EntryField.chargingPrice,
      EntryField.soc,
      EntryField.fuelPrice,
      EntryField.parkingRate,
      EntryField.tollDistance,
      EntryField.insurancePeriod,
    };
    if (validation.field != null && fields.contains(validation.field)) {
      return validation.message;
    }
    return null;
  }
}

class _ChargingParams extends ConsumerWidget {
  const _ChargingParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! ChargingDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    final socEnd = detail.socEnd;
    final capacity = state.defaults.batteryCapacityKwh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldCell(
                label: '充入电量 (kWh)',
                value: detail.kwh == null ? '—' : formatOneDecimal(detail.kwh!),
                unit: '度',
                unitColor: context.palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FieldCell(
                label: '综合单价 (¥/kWh)',
                child: _SyncedNumericField(
                  value: formatYuanInput(detail.unitPriceCentsPerKwh),
                  decimal: true,
                  suffix: '含服务费',
                  textAlign: TextAlign.left,
                  onTextChanged: (text) {
                    final cents = parseYuanToCents(text);
                    if (cents != null) {
                      controller.setChargingPrice(cents);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        if (capacity != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '补能前后电量百分比 (SOC)',
                      style: AppTypography.labelSm.copyWith(
                        color: context.palette.outline,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      socEnd == null
                          ? ''
                          : '补能 +${(socEnd - detail.socStart).clamp(0, 100)}%',
                      style: AppTypography.labelSm.copyWith(
                        color: context.palette.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '开始',
                      style: AppTypography.labelSm.copyWith(
                        color: context.palette.outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 52,
                      child: _SyncedNumericField(
                        value: detail.socStart.toString(),
                        decimal: false,
                        suffix: '%',
                        textAlign: TextAlign.center,
                        onTextChanged: (text) {
                          final value = int.tryParse(text);
                          if (value != null) {
                            controller.setSocStart(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 12,
                          child: Stack(
                            children: [
                              Container(color: context.palette.outlineVariant),
                              FractionallySizedBox(
                                widthFactor: (detail.socStart / 100).clamp(
                                  0.0,
                                  1.0,
                                ),
                                child: ColoredBox(
                                  color: context.palette.outlineVariant,
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: ((socEnd ?? detail.socStart) / 100)
                                    .clamp(0.0, 1.0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.palette.primary.withValues(
                                          alpha: 0.45,
                                        ),
                                        context.palette.primary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '结束',
                      style: AppTypography.labelSm.copyWith(
                        color: context.palette.outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.palette.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        socEnd == null ? '—' : formatSoc(socEnd),
                        style: AppTypography.labelMd.copyWith(
                          color: context.palette.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FuelParams extends ConsumerWidget {
  const _FuelParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! FuelDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldCell(
                label: '加注油量 (L)',
                value: detail.liters == null
                    ? '—'
                    : formatTwoDecimals(detail.liters!),
                unit: '升',
                unitColor: context.palette.secondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FieldCell(
                label: '燃油单价 (¥/L)',
                child: _SyncedNumericField(
                  value: formatYuanInput(detail.unitPriceCentsPerLiter),
                  decimal: true,
                  suffix: '${detail.fuelGrade}# 汽油',
                  textAlign: TextAlign.left,
                  onTextChanged: (text) {
                    final cents = parseYuanToCents(text);
                    if (cents != null) {
                      controller.setFuelPrice(cents);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                '油品标号选择',
                style: AppTypography.labelSm.copyWith(
                  color: context.palette.outline,
                ),
              ),
              const Spacer(),
              for (final grade in const [92, 95, 98]) ...[
                _ChoiceChip(
                  label: '$grade#',
                  selected: detail.fuelGrade == grade,
                  selectedColor: context.palette.secondary,
                  onTap: () => controller.setFuelGrade(grade),
                ),
                if (grade != 98) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParkingParams extends ConsumerWidget {
  const _ParkingParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! ParkingDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldCell(
                label: '停车时长',
                value: detail.durationMinutes == null
                    ? '—'
                    : formatDuration(detail.durationMinutes!),
                unit: '时',
                unitColor: context.palette.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FieldCell(
                label: '场地单价 (¥/小时)',
                child: _SyncedNumericField(
                  value: formatYuanInput(detail.rateCentsPerHour),
                  decimal: true,
                  suffix: '/ 小时',
                  textAlign: TextAlign.left,
                  onTextChanged: (text) {
                    final cents = parseYuanToCents(text);
                    if (cents != null) {
                      controller.setParkingRate(cents);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '停车场名称',
          child: _SyncedTextField(
            value: detail.lotName,
            hint: '如 科技园地下二层车库',
            maxLength: 30,
            onChanged: controller.setPlace,
          ),
        ),
      ],
    );
  }
}

class _TollParams extends ConsumerWidget {
  const _TollParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! TollDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldCell(
                label: '入口收费站',
                child: _SyncedTextField(
                  value: detail.entryStation,
                  hint: '南山收费站',
                  maxLength: 20,
                  onChanged: (value) => controller.setDetail(
                    detail.copyWith(
                      entryStation: value,
                      clearEntryStation: value == null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FieldCell(
                label: '出口收费站',
                child: _SyncedTextField(
                  value: detail.exitStation,
                  hint: '松岗收费站',
                  maxLength: 20,
                  onChanged: (value) =>
                      controller.setDetail(detail.copyWith(exitStation: value)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '通行路段',
          child: _SyncedTextField(
            value: detail.roadName,
            hint: '如 广深沿江高速 (S3)',
            maxLength: 30,
            onChanged: (value) =>
                controller.setDetail(detail.copyWith(roadName: value)),
          ),
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '通行里程 (km)',
          child: _SyncedNumericField(
            value: detail.distanceKm?.toString() ?? '',
            decimal: false,
            suffix: 'km',
            textAlign: TextAlign.right,
            onTextChanged: (text) {
              final value = int.tryParse(text);
              controller.setDetail(
                value == null
                    ? detail.copyWith(clearDistance: true)
                    : detail.copyWith(distanceKm: value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MaintenanceParams extends ConsumerWidget {
  const _MaintenanceParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! MaintenanceDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldCell(
          label: '保养项目',
          child: _SyncedTextField(
            value: detail.item,
            hint: '如 小保养 / 更换刹车片',
            maxLength: 30,
            onChanged: (value) =>
                controller.setDetail(detail.copyWith(item: value)),
          ),
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '服务门店',
          child: _SyncedTextField(
            value: detail.shopName,
            hint: '保养门店名称',
            maxLength: 30,
            onChanged: controller.setPlace,
          ),
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '当前里程 (km)',
          child: _SyncedNumericField(
            value: detail.odometerKm?.toString() ?? '',
            decimal: false,
            suffix: 'km',
            textAlign: TextAlign.right,
            onTextChanged: (text) {
              final value = int.tryParse(text);
              controller.setOdometerKm(value);
            },
          ),
        ),
      ],
    );
  }
}

class _CarWashParams extends ConsumerWidget {
  const _CarWashParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! CarWashDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    const types = ['标准洗车', '精洗', '内饰清洁', '其他'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in types)
              _ChoiceChip(
                label: type,
                selected: detail.serviceType == type,
                onTap: () =>
                    controller.setDetail(detail.copyWith(serviceType: type)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '服务门店',
          child: _SyncedTextField(
            value: detail.shopName,
            hint: '洗车门店名称',
            maxLength: 30,
            onChanged: controller.setPlace,
          ),
        ),
      ],
    );
  }
}

class _InsuranceParams extends ConsumerWidget {
  const _InsuranceParams({required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseEntryControllerProvider(args));
    final detail = state.draft.detail;
    if (detail is! InsuranceDetail) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    const types = ['交强险', '商业险', '车船税', '其他'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in types)
              _ChoiceChip(
                label: type,
                selected: detail.coverageType == type,
                onTap: () =>
                    controller.setDetail(detail.copyWith(coverageType: type)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '保单号',
          child: _SyncedTextField(
            value: detail.policyNo,
            hint: '选填，仅展示后 6 位',
            maxLength: 30,
            onChanged: (value) =>
                controller.setDetail(detail.copyWith(policyNo: value)),
          ),
        ),
        const SizedBox(height: 12),
        _FieldCell(
          label: '保障周期',
          child: InkWell(
            onTap: () => _pickPeriod(context, controller, detail),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _periodText(detail),
                      style: AppTypography.bodyMd.copyWith(
                        color: detail.periodStart == null
                            ? context.palette.outline
                            : context.palette.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: context.palette.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _periodText(InsuranceDetail detail) {
    final start = detail.periodStart;
    final end = detail.periodEnd;
    if (start == null || end == null) {
      return '未选择';
    }
    return '${_date(start)} 至 ${_date(end)}';
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickPeriod(
    BuildContext context,
    ExpenseEntryController controller,
    InsuranceDetail detail,
  ) async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
      initialDateRange: detail.periodStart != null && detail.periodEnd != null
          ? DateTimeRange(start: detail.periodStart!, end: detail.periodEnd!)
          : null,
      helpText: '选择保障周期',
      saveText: '确定',
    );
    if (result == null || !context.mounted) {
      return;
    }
    controller.setDetail(
      detail.copyWith(periodStart: result.start, periodEnd: result.end),
    );
  }
}

class _FieldCell extends StatelessWidget {
  const _FieldCell({
    required this.label,
    this.value,
    this.child,
    this.unit,
    this.unitColor,
  });

  final String label;
  final String? value;
  final Widget? child;
  final String? unit;
  final Color? unitColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(color: palette.outline),
          ),
          const SizedBox(height: 4),
          if (child != null)
            child!
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                ),
                if (unit != null)
                  Text(
                    unit!,
                    style: AppTypography.labelSm.copyWith(
                      color: unitColor ?? palette.outline,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SyncedTextField extends StatefulWidget {
  const _SyncedTextField({
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLength = 30,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final int maxLength;

  @override
  State<_SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<_SyncedTextField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && (widget.value ?? '') != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLength: widget.maxLength,
      maxLines: 1,
      style: AppTypography.bodyMd.copyWith(
        color: context.palette.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration.collapsed(
        hintText: widget.hint,
        hintStyle: AppTypography.bodyMd.copyWith(
          color: context.palette.outlineVariant,
          fontWeight: FontWeight.w400,
        ),
      ).copyWith(counterText: ''),
      onChanged: (text) => widget.onChanged(text.trim().isEmpty ? null : text),
    );
  }
}

class _SyncedNumericField extends StatefulWidget {
  const _SyncedNumericField({
    required this.value,
    required this.onTextChanged,
    required this.decimal,
    this.suffix,
    this.textAlign = TextAlign.right,
  });

  final String value;
  final ValueChanged<String> onTextChanged;
  final bool decimal;
  final String? suffix;
  final TextAlign textAlign;

  @override
  State<_SyncedNumericField> createState() => _SyncedNumericFieldState();
}

class _SyncedNumericFieldState extends State<_SyncedNumericField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _controller.text = widget.value;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SyncedNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimal,
            ),
            textAlign: widget.textAlign,
            maxLength: widget.decimal ? 10 : 7,
            inputFormatters: [
              if (widget.decimal)
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  if (text.isEmpty ||
                      RegExp(r'^\d{0,6}(\.\d{0,2})?$').hasMatch(text)) {
                    return newValue;
                  }
                  return oldValue;
                })
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            style: AppTypography.headlineSm.copyWith(
              color: context.palette.onSurface,
            ),
            decoration: InputDecoration.collapsed(
              hintText: widget.decimal ? '0.00' : '0',
              hintStyle: AppTypography.headlineSm.copyWith(
                color: context.palette.outlineVariant,
              ),
            ).copyWith(counterText: ''),
            onChanged: widget.onTextChanged,
          ),
        ),
        if (widget.suffix != null) ...[
          const SizedBox(width: 4),
          Text(
            widget.suffix!,
            maxLines: 1,
            style: AppTypography.labelSm.copyWith(
              color: context.palette.outline,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selectedColor ?? palette.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? color : palette.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: selected ? Colors.white : palette.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
