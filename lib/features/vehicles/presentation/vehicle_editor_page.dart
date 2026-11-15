import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/domain/enums.dart';
import '../../../core/presentation/toast.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_error.dart';
import '../domain/providers.dart';
import '../domain/vehicle_editor_models.dart';
import '../domain/vehicle_editor_presenter.dart';
import '../domain/vehicle_editor_providers.dart';
import 'vehicle_editor_style.dart';
import 'widgets/discard_changes_sheet.dart';
import 'widgets/powertrain_selector.dart';
import 'widgets/province_picker_sheet.dart';
import 'widgets/vehicle_editor_bottom_bar.dart';
import 'widgets/vehicle_editor_field.dart';
import 'widgets/vehicle_editor_header.dart';
import 'widgets/vehicle_editor_skeleton.dart';
import 'widgets/vehicle_plate_input.dart';
import 'widgets/vehicle_confirm_sheets.dart';

class VehicleEditorPage extends ConsumerStatefulWidget {
  const VehicleEditorPage({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<VehicleEditorPage> createState() => _VehicleEditorPageState();
}

class _VehicleEditorPageState extends ConsumerState<VehicleEditorPage> {
  late final VehicleEditorArgs _args;
  final _scrollController = ScrollController();

  final _name = TextEditingController();
  final _specLabel = TextEditingController();
  final _nickname = TextEditingController();
  final _plate = TextEditingController();
  final _odometer = TextEditingController();
  final _battery = TextEditingController();
  final _officialConsumption = TextEditingController();
  final _electricRange = TextEditingController();
  final _tank = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _nextMaintenance = TextEditingController();

  bool _allowPop = false;
  bool _didInitialSync = false;

  @override
  void initState() {
    super.initState();
    _args = widget.vehicleId == null
        ? const VehicleEditorArgs.create()
        : VehicleEditorArgs.edit(widget.vehicleId!);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in [
      _name,
      _specLabel,
      _nickname,
      _plate,
      _odometer,
      _battery,
      _officialConsumption,
      _electricRange,
      _tank,
      _purchasePrice,
      _nextMaintenance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  VehicleEditorController get _controller =>
      ref.read(vehicleEditorControllerProvider(_args).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleEditorControllerProvider(_args));
    ref.listen(vehicleEditorControllerProvider(_args), (previous, next) {
      if (next.status != VehicleEditorStatus.ready) {
        return;
      }
      final becameReady = previous?.status != VehicleEditorStatus.ready;
      final powertrainChanged =
          previous?.draft.powertrain != next.draft.powertrain;
      if (becameReady || powertrainChanged) {
        _syncControllers(next.draft);
      }
    });
    if (!_didInitialSync && state.status == VehicleEditorStatus.ready) {
      _didInitialSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncControllers(state.draft);
        }
      });
    }

    final palette = context.palette;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: SafeArea(
              top: true,
              bottom: false,
              child: PopScope(
                canPop: _allowPop || (!state.isSaving && !state.isDirty),
                onPopInvokedWithResult: (didPop, result) {
                  if (!didPop) {
                    _handleBack(state);
                  }
                },
                child: Column(
                  children: [
                    VehicleEditorHeader(
                      state: state,
                      onBack: () => _handleBack(state),
                    ),
                    Expanded(child: _body(state)),
                    if (state.status == VehicleEditorStatus.ready)
                      VehicleEditorBottomBar(
                        state: state,
                        onSave: () => _save(state),
                        onArchive: () => _archive(state),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(VehicleEditorState state) {
    return switch (state.status) {
      VehicleEditorStatus.loading => const VehicleEditorSkeleton(),
      VehicleEditorStatus.ready => AbsorbPointer(
        absorbing: state.isSaving,
        child: _buildForm(state),
      ),
      VehicleEditorStatus.notFound => _EditorErrorState(
        icon: Icons.car_crash_rounded,
        title: '车辆档案不存在',
        message: '该车辆可能已被删除，请返回车库刷新。',
        onAction: () => _popWithResult(null),
      ),
      VehicleEditorStatus.archived => _EditorErrorState(
        icon: Icons.inventory_2_rounded,
        title: '该车辆已归档',
        message: '归档车辆不可编辑，请在「已归档车辆」中恢复后再修改。',
        onAction: () => _popWithResult(null),
      ),
      VehicleEditorStatus.error => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: SectionError(
          message: '车辆档案加载失败',
          onRetry: () => ref.invalidate(vehicleEditorControllerProvider(_args)),
        ),
      ),
    };
  }

  Widget _buildForm(VehicleEditorState state) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        PowertrainSelector(
          value: state.draft.powertrain,
          onChanged: _controller.setPowertrain,
          enabled: !state.isSaving,
        ),
        const SizedBox(height: VehicleEditorStyle.cardGap),
        _identityCard(state),
        const SizedBox(height: VehicleEditorStyle.cardGap),
        _specsCard(state),
        const SizedBox(height: VehicleEditorStyle.cardGap),
        _preferencesCard(state),
      ],
    );
  }

  Widget _identityCard(VehicleEditorState state) {
    final palette = context.palette;
    final errors = state.fieldErrors;
    return EditorSectionCard(
      icon: Icons.directions_car_rounded,
      title: '车辆身份信息',
      subtitle: '品牌、车系与车牌基础档案',
      color: palette.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EditorFieldLabel('品牌与车型'),
          TextField(
            key: const Key('editor-name'),
            controller: _name,
            onChanged: _controller.setName,
            textInputAction: TextInputAction.next,
            style: AppTypography.bodyLg.copyWith(color: palette.onSurface),
            decoration: editorInputDecoration(context, hint: '例如：极氪 001 YOU版'),
          ),
          if (errors[VehicleEditorField.name] != null)
            EditorErrorText(errors[VehicleEditorField.name]!),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < VehicleEditorPresenter.quickModels.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 6),
                  _QuickChip(
                    label: VehicleEditorPresenter.quickModels[index],
                    onTap: () {
                      final model = VehicleEditorPresenter.quickModels[index];
                      _name.text = model;
                      _controller.setName(model);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const EditorFieldLabel('配置版本（选填）'),
          TextField(
            key: const Key('editor-spec-label'),
            controller: _specLabel,
            onChanged: _controller.setSpecLabel,
            textInputAction: TextInputAction.next,
            style: AppTypography.bodyMd.copyWith(color: palette.onSurface),
            decoration: editorInputDecoration(context, hint: '例如：2023款 创世旗舰型'),
          ),
          if (errors[VehicleEditorField.specLabel] != null)
            EditorErrorText(errors[VehicleEditorField.specLabel]!),
          const SizedBox(height: 14),
          VehiclePlateInput(
            controller: _plate,
            fieldKey: const Key('editor-plate'),
            province: state.draft.province,
            green: state.draft.isGreenPlate,
            error: errors[VehicleEditorField.plate],
            enabled: !state.isSaving,
            onProvinceTap: () => _pickProvince(state),
            onGreenChanged: (_) => _controller.toggleGreenPlate(),
            onChanged: _controller.setPlateBody,
          ),
          const SizedBox(height: 14),
          _NumberField(
            fieldKey: const Key('editor-odometer'),
            label: '当前总里程 (公里)',
            controller: _odometer,
            unit: 'km',
            integer: true,
            error: errors[VehicleEditorField.odometer],
            onChanged: (text) => _controller.setOdometer(int.tryParse(text)),
          ),
          EditorHelperText(
            '用于核算后续每笔充电 / 加油后的综合单公里成本',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _specsCard(VehicleEditorState state) {
    final palette = context.palette;
    final type = state.draft.powertrain;
    final errors = state.fieldErrors;
    final electric = VehicleEditorPresenter.isElectric(type);
    final fuel = VehicleEditorPresenter.isFuel(type);

    final specFields = <Widget>[];
    if (type == PowertrainType.phev) {
      specFields.add(
        _NumberField(
          fieldKey: const Key('editor-electric-range'),
          label: '纯电续航 (WLTC)',
          controller: _electricRange,
          unit: 'km',
          integer: true,
          error: errors[VehicleEditorField.electricRange],
          onChanged: (text) => _controller.setElectricRange(int.tryParse(text)),
        ),
      );
    }
    if (electric) {
      specFields.add(
        _NumberField(
          fieldKey: const Key('editor-battery'),
          label: '动力电池容量',
          controller: _battery,
          unit: 'kWh',
          error: errors[VehicleEditorField.battery],
          onChanged: (text) => _controller.setBattery(double.tryParse(text)),
        ),
      );
    }
    if (fuel) {
      specFields.add(
        _NumberField(
          fieldKey: const Key('editor-tank'),
          label: '油箱容积',
          controller: _tank,
          unit: 'L',
          error: errors[VehicleEditorField.tank],
          onChanged: (text) => _controller.setTank(double.tryParse(text)),
        ),
      );
    }
    specFields.add(
      _NumberField(
        fieldKey: const Key('editor-official-consumption'),
        label: VehicleEditorPresenter.fuelConsumptionLabel(type),
        controller: _officialConsumption,
        unit: VehicleEditorPresenter.fuelConsumptionUnit(type),
        error: errors[VehicleEditorField.officialConsumption],
        onChanged: (text) =>
            _controller.setOfficialConsumption(double.tryParse(text)),
      ),
    );

    return EditorSectionCard(
      icon: Icons.tune_rounded,
      title: '动力与能耗基准',
      subtitle: '官方标称数据，用于能耗核算参考',
      color: palette.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < specFields.length; index += 2) ...[
            if (index > 0) const SizedBox(height: 12),
            if (index + 1 < specFields.length)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: specFields[index]),
                  const SizedBox(width: 12),
                  Expanded(child: specFields[index + 1]),
                ],
              )
            else
              specFields[index],
          ],
          if (fuel) ...[
            const SizedBox(height: 14),
            const EditorFieldLabel('默认油品（选填）'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final grade in VehicleEditorPresenter.fuelGrades)
                  ChoiceChip(
                    label: Text('$grade'),
                    selected: state.draft.defaultFuelGrade == grade,
                    onSelected: (selected) =>
                        _controller.setFuelGrade(selected ? grade : null),
                    selectedColor: palette.secondary.withValues(alpha: 0.18),
                    labelStyle: AppTypography.labelMd.copyWith(
                      color: state.draft.defaultFuelGrade == grade
                          ? palette.secondaryText
                          : palette.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: state.draft.defaultFuelGrade == grade
                          ? palette.secondary.withValues(alpha: 0.5)
                          : palette.outlineVariant,
                    ),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DateField(
                  label: '首次上牌 / 购车时间',
                  value: state.draft.purchaseDate,
                  placeholder: '选择日期',
                  error: errors[VehicleEditorField.purchaseDate],
                  onTap: () => _pickPurchaseDate(state),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  fieldKey: const Key('editor-purchase-price'),
                  label: '购车落地价（选填）',
                  controller: _purchasePrice,
                  unit: '万元',
                  decimals: 2,
                  error: errors[VehicleEditorField.purchasePrice],
                  onChanged: (text) => _controller.setPurchasePrice(
                    VehicleEditorPresenter.parseWanToCents(text),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preferencesCard(VehicleEditorState state) {
    final palette = context.palette;
    final errors = state.fieldErrors;
    return EditorSectionCard(
      icon: Icons.verified_user_rounded,
      title: '周期提醒与偏好',
      subtitle: '保养计划与专属驾驶标识',
      color: palette.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EditorFieldLabel('爱车昵称'),
          TextField(
            key: const Key('editor-nickname'),
            controller: _nickname,
            onChanged: _controller.setNickname,
            maxLength: 12,
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            style: AppTypography.bodyMd.copyWith(color: palette.onSurface),
            decoration: editorInputDecoration(
              context,
              hint: '给爱车起个亲切名字（如：大白、追风者）',
            ),
          ),
          if (errors[VehicleEditorField.nickname] != null)
            EditorErrorText(errors[VehicleEditorField.nickname]!),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(
                VehicleEditorStyle.innerRadius,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '设为默认主座驾',
                        style: AppTypography.labelLg.copyWith(
                          color: palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        state.isPrimaryLocked
                            ? '默认主驾需在车辆管理中切换'
                            : '首页仪表盘与单手快捷记账优先展示',
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  key: const Key('editor-primary-switch'),
                  value: state.draft.makePrimary,
                  onChanged: state.isPrimaryLocked
                      ? null
                      : (_) => _controller.togglePrimary(),
                  activeTrackColor: palette.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NumberField(
                  fieldKey: const Key('editor-next-maintenance'),
                  label: '下次保养里程',
                  controller: _nextMaintenance,
                  unit: 'km',
                  integer: true,
                  error: errors[VehicleEditorField.nextMaintenance],
                  onChanged: (text) =>
                      _controller.setNextMaintenance(int.tryParse(text)),
                  helper: _maintenanceHint(state),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: '车险到期时间',
                  value: state.draft.insuranceExpiry,
                  placeholder: '选择日期',
                  error: errors[VehicleEditorField.insuranceExpiry],
                  onTap: () => _pickInsuranceDate(state),
                  helper: _insuranceHint(state),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _maintenanceHint(VehicleEditorState state) {
    final next = state.draft.nextMaintenanceKm;
    final odometer = state.draft.odometerKm;
    if (next == null || odometer == null) {
      return null;
    }
    if (next <= odometer) {
      return '将显示为已超期';
    }
    return null;
  }

  String? _insuranceHint(VehicleEditorState state) {
    final expiry = state.draft.insuranceExpiry;
    if (expiry == null) {
      return null;
    }
    final today = VehicleEditorPresenter.dateOnly(DateTime.now());
    if (expiry.isBefore(today)) {
      return '已过期';
    }
    return null;
  }

  Future<void> _pickProvince(VehicleEditorState state) async {
    final province = await showProvincePicker(
      context,
      selected: state.draft.province,
    );
    if (province != null && mounted) {
      _controller.setProvince(province);
      showAppToast(context, '已选择车牌简称「$province」');
    }
  }

  Future<void> _pickPurchaseDate(VehicleEditorState state) async {
    final today = VehicleEditorPresenter.dateOnly(DateTime.now());
    final raw = state.draft.purchaseDate ?? today;
    final initial = raw.isBefore(DateTime(1980))
        ? DateTime(1980)
        : (raw.isAfter(today) ? today : raw);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: today,
      helpText: '选择首次上牌 / 购车时间',
    );
    if (picked != null && mounted) {
      _controller.setPurchaseDate(picked);
    }
  }

  Future<void> _pickInsuranceDate(VehicleEditorState state) async {
    final today = VehicleEditorPresenter.dateOnly(DateTime.now());
    final raw = state.draft.insuranceExpiry ?? today;
    final initial = raw.isBefore(DateTime(1980))
        ? DateTime(1980)
        : (raw.isAfter(DateTime(2100, 12, 31)) ? DateTime(2100, 12, 31) : raw);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择车险到期时间',
    );
    if (picked != null && mounted) {
      _controller.setInsuranceExpiry(picked);
    }
  }

  Future<void> _save(VehicleEditorState state) async {
    final result = await _controller.save();
    if (!mounted) {
      return;
    }
    if (result == null) {
      final current = ref.read(vehicleEditorControllerProvider(_args));
      if (current.fieldErrors.isNotEmpty && _scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    final name = state.draft.name.trim();
    showAppToast(
      context,
      VehicleEditorPresenter.successMessageOf(
        name: name,
        created: result.created,
        primary: state.draft.makePrimary,
        archived: false,
      ),
    );
    _popWithResult(result);
  }

  Future<void> _archive(VehicleEditorState state) async {
    final vehicleId = state.args.vehicleId;
    if (vehicleId == null || state.isSaving) {
      return;
    }
    if (state.isDirty) {
      final discard = await showDiscardChangesSheet(context);
      if (discard != true || !mounted) {
        return;
      }
    }
    final savedDraft = state.initialDraft ?? state.draft;
    final vehicle = VehicleEditorPresenter.buildVehicle(
      draft: savedDraft,
      id: vehicleId,
      badge: null,
    );
    final body = state.isOnlyActiveVehicle
        ? '归档后车库将为空，首页仪表盘与快捷记账将显示空状态；历史流水、报表与凭证完整保留。'
        : state.successorName != null
        ? '归档后，默认主驾将由「${state.successorName}」接任；历史流水、报表与凭证完整保留，可随时在「已归档车辆」恢复。'
        : '归档后该车辆将移出常用车库，首页仪表盘与快捷记账不再展示；历史流水、报表与凭证完整保留，可随时在「已归档车辆」恢复。';
    final confirmed = await showArchiveVehicleSheet(
      context,
      vehicle,
      body: body,
      confirmLabel: state.isOnlyActiveVehicle ? '确认归档并清空车库' : '确认归档',
      onConfirm: () async {
        final ok = await ref
            .read(vehicleCommandProvider.notifier)
            .archive(vehicleId);
        return ok ? null : ref.read(vehicleCommandProvider).errorMessage;
      },
    );
    if (confirmed == true && mounted) {
      showAppToast(
        context,
        VehicleEditorPresenter.successMessageOf(
          name: vehicle.name,
          created: false,
          primary: false,
          archived: true,
        ),
      );
      _popWithResult(
        VehicleEditorResult(
          vehicleId: vehicleId,
          created: false,
          archived: true,
        ),
      );
    }
  }

  Future<void> _handleBack(VehicleEditorState state) async {
    if (state.isSaving) {
      return;
    }
    if (state.isDirty) {
      final discard = await showDiscardChangesSheet(context);
      if (discard == true && mounted) {
        _popWithResult(null);
      }
      return;
    }
    _popWithResult(null);
  }

  void _popWithResult(VehicleEditorResult? result) {
    if (!mounted || _allowPop) {
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  void _syncControllers(VehicleEditorDraft draft) {
    _syncText(_name, draft.name);
    _syncText(_specLabel, draft.specLabel);
    _syncText(_nickname, draft.nickname);
    _syncText(_plate, VehicleEditorPresenter.formatPlateBody(draft.plateBody));
    _syncText(_odometer, _intText(draft.odometerKm));
    _syncText(_battery, _doubleText(draft.batteryCapacityKwh));
    _syncText(_officialConsumption, _doubleText(draft.officialConsumption));
    _syncText(_electricRange, _intText(draft.electricRangeKm));
    _syncText(_tank, _doubleText(draft.tankCapacityL));
    _syncText(
      _purchasePrice,
      VehicleEditorPresenter.formatWanInput(draft.purchasePriceCents),
    );
    _syncText(_nextMaintenance, _intText(draft.nextMaintenanceKm));
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _intText(int? value) => value?.toString() ?? '';

  String _doubleText(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceContainer,
      borderRadius: BorderRadius.circular(context.tokens.radiusPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: palette.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.unit,
    required this.onChanged,
    this.fieldKey,
    this.integer = false,
    this.decimals = 1,
    this.error,
    this.helper,
  });

  final Key? fieldKey;
  final String label;
  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onChanged;
  final bool integer;
  final int decimals;
  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorFieldLabel(label),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          onChanged: onChanged,
          style: AppTypography.headlineSm.copyWith(
            fontSize: 15,
            color: palette.onSurface,
          ),
          inputFormatters: [
            if (integer)
              FilteringTextInputFormatter.digitsOnly
            else
              TextInputFormatter.withFunction((oldValue, newValue) {
                return RegExp('^\\d*\\.?\\d{0,$decimals}\$')
                        .hasMatch(newValue.text)
                    ? newValue
                    : oldValue;
              }),
          ],
          decoration: editorInputDecoration(context, suffixText: unit),
        ),
        if (error != null) EditorErrorText(error!),
        if (helper != null)
          EditorHelperText(helper!, color: palette.secondaryText),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.error,
    this.helper,
  });

  final String label;
  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorFieldLabel(label),
        Material(
          color: palette.surfaceContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(VehicleEditorStyle.innerRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: VehicleEditorStyle.inputHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value == null
                            ? placeholder
                            : VehicleEditorPresenter.formatInputDate(value!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd.copyWith(
                          color: value == null
                              ? palette.outline
                              : palette.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: palette.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (error != null) EditorErrorText(error!),
        if (helper != null)
          EditorHelperText(helper!, color: palette.secondaryText),
      ],
    );
  }
}

class _EditorErrorState extends StatelessWidget {
  const _EditorErrorState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: AppCard(
          radius: VehicleEditorStyle.cardRadius,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: palette.outline),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(
                  color: palette.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: palette.outline,
                  height: 20 / 13,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('返回车库'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
