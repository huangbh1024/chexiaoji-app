import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_models.dart';
import '../../domain/vehicle_presenter.dart';
import '../archived_vehicles_style.dart';
import 'vehicle_sheet_shell.dart';

Future<bool?> showPurgeArchivedVehicleSheet(
  BuildContext context,
  ArchivedVehicleSummary vehicle, {
  required Future<String?> Function(String plateTail) onConfirm,
}) {
  return showVehicleSheet<bool>(
    context,
    (_) => _PurgeArchivedVehicleSheet(vehicle: vehicle, onConfirm: onConfirm),
    maxHeightFactor: ArchivedVehiclesStyle.dangerSheetMaxHeight,
    isDismissible: false,
    enableDrag: false,
  );
}

class _PurgeArchivedVehicleSheet extends StatefulWidget {
  const _PurgeArchivedVehicleSheet({
    required this.vehicle,
    required this.onConfirm,
  });

  final ArchivedVehicleSummary vehicle;
  final Future<String?> Function(String plateTail) onConfirm;

  @override
  State<_PurgeArchivedVehicleSheet> createState() =>
      _PurgeArchivedVehicleSheetState();
}

class _PurgeArchivedVehicleSheetState
    extends State<_PurgeArchivedVehicleSheet> {
  late final TextEditingController _tailController = TextEditingController();
  late final String _expectedTail = ArchivedVehiclePresenter.plateTailOf(
    widget.vehicle.vehicle.plate,
  );

  bool _acknowledged = false;
  bool _submitting = false;
  String? _error;

  bool get _hasExpectedTail => _expectedTail.isNotEmpty;

  bool get _tailMatches =>
      _hasExpectedTail &&
      _tailController.text.trim().toUpperCase() == _expectedTail;

  bool get _canSubmit =>
      _hasExpectedTail && _tailMatches && _acknowledged && !_submitting;

  @override
  void dispose() {
    _tailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onConfirm(_expectedTail);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final vehicle = widget.vehicle;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_submitting,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DangerHeader(),
            const SizedBox(height: 12),
            Text(
              '彻底删除车辆档案？',
              textAlign: TextAlign.center,
              style: AppTypography.headlineMd.copyWith(
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: palette.errorSoft.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: palette.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '不可撤销的高风险清除操作',
                      style: AppTypography.labelMd.copyWith(
                        color: palette.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _TargetVehicleCard(vehicle: vehicle),
            const SizedBox(height: 12),
            _ImpactList(vehicle: vehicle),
            const SizedBox(height: 16),
            _TailConfirmField(
              controller: _tailController,
              expectedTail: _expectedTail,
              enabled: !_submitting,
              matched: _tailMatches,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _AcknowledgeRow(
              checked: _acknowledged,
              enabled: !_submitting,
              onChanged: (value) => setState(() => _acknowledged = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: palette.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _WideButton(
              label: '暂不删除，保留归档',
              icon: Icons.shield_rounded,
              background: palette.surfaceContainer,
              foreground: palette.onSurface,
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 10),
            _WideButton(
              label: '彻底销毁座驾档案',
              icon: Icons.delete_sweep_rounded,
              background: palette.error,
              foreground: Colors.white,
              busy: _submitting,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerHeader extends StatelessWidget {
  const _DangerHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: SizedBox(
        width: ArchivedVehiclesStyle.dangerIconSize + 8,
        height: ArchivedVehiclesStyle.dangerIconSize + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: ArchivedVehiclesStyle.dangerIconSize,
                height: ArchivedVehiclesStyle.dangerIconSize,
                decoration: BoxDecoration(
                  color: palette.errorSoft,
                  borderRadius: BorderRadius.circular(
                    ArchivedVehiclesStyle.dangerIconRadius,
                  ),
                  border: Border.all(
                    color: palette.error.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  size: 30,
                  color: palette.error,
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetVehicleCard extends StatelessWidget {
  const _TargetVehicleCard({required this.vehicle});

  final ArchivedVehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = vehicle.powertrain.color;
    final powertrain = vehicle.vehicle.powertrainLabel.isEmpty
        ? vehicle.powertrain.label
        : vehicle.vehicle.powertrainLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  size: 22,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.specLabel.trim().isEmpty
                          ? vehicle.vehicle.name
                          : '${vehicle.vehicle.name} ${vehicle.specLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLg.copyWith(
                        color: palette.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _MiniPlate(plate: vehicle.vehicle.plate),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            powertrain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: palette.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '封存状态',
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ArchivedVehiclePresenter.archiveDurationLabel(
                      vehicle.archivedAt,
                    ),
                    style: AppTypography.labelMd.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '历史总里程',
                style: AppTypography.bodySm.copyWith(color: palette.outline),
              ),
              const Spacer(),
              Text(
                formatKm(vehicle.vehicle.odometerKm),
                style: AppTypography.labelMd.copyWith(
                  color: palette.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactList extends StatelessWidget {
  const _ImpactList({required this.vehicle});

  final ArchivedVehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.errorSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.error.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_rounded, size: 16, color: palette.error),
              const SizedBox(width: 6),
              Text(
                '删除影响清单',
                style: AppTypography.labelMd.copyWith(
                  color: palette.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: palette.error.withValues(alpha: 0.15)),
          const SizedBox(height: 10),
          _ImpactItem(
            icon: Icons.receipt_long_rounded,
            title: '历史账单解除车辆归属',
            body: ArchivedVehiclePresenter.impactRecordsText(vehicle),
          ),
          const SizedBox(height: 12),
          const _ImpactItem(
            icon: Icons.show_chart_rounded,
            title: '能耗档案清空且不可复原',
            body:
                '该车的百公里能耗曲线、按车统计与电池健康分析将不再可查看；'
                '已导出的报表文件与账单总额不受影响。',
          ),
          const SizedBox(height: 12),
          const _ImpactItem(
            icon: Icons.lock_rounded,
            title: '不可逆销毁',
            body: '删除后无法恢复，重新添加需重新录入车辆参数。',
          ),
        ],
      ),
    );
  }
}

class _ImpactItem extends StatelessWidget {
  const _ImpactItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: palette.error),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: palette.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTypography.bodySm.copyWith(
                  color: palette.outline,
                  height: 17 / 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TailConfirmField extends StatelessWidget {
  const _TailConfirmField({
    required this.controller,
    required this.expectedTail,
    required this.enabled,
    required this.matched,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String expectedTail;
  final bool enabled;
  final bool matched;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasTail = expectedTail.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasTail ? '输入车牌尾号确认删除' : '该车辆缺少车牌，无法确认删除',
                style: AppTypography.labelMd.copyWith(
                  color: palette.onSurfaceVariant,
                ),
              ),
            ),
            if (hasTail)
              Text(
                expectedTail,
                style: AppTypography.labelMd.copyWith(
                  color: palette.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled && hasTail,
          maxLength: 5,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\s·•\-]')),
            LengthLimitingTextInputFormatter(5),
            _UpperCaseTextFormatter(),
          ],
          onChanged: onChanged,
          style: AppTypography.labelLg.copyWith(
            color: palette.onSurface,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hasTail ? '请输入 $expectedTail' : '—',
            counterText: '',
            filled: true,
            fillColor: palette.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: palette.outlineVariant.withValues(alpha: 0.70),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.error, width: 1.4),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.outlineVariant),
            ),
            hintStyle: AppTypography.bodyMd.copyWith(color: palette.outline),
            suffixIcon: matched
                ? Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: palette.primaryText,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _AcknowledgeRow extends StatelessWidget {
  const _AcknowledgeRow({
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      checked: checked,
      label: '我已了解该车辆档案将被永久删除，历史流水将失去车辆归属。',
      child: InkWell(
        onTap: enabled ? () => onChanged(!checked) : null,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: checked ? palette.error : palette.surface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: checked ? palette.error : palette.outlineVariant,
                    width: 1.4,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '我已了解该车辆档案将被永久删除，历史流水将失去车辆归属。',
                  style: AppTypography.bodySm.copyWith(
                    color: palette.onSurfaceVariant,
                    height: 17 / 11,
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

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.40),
          disabledForegroundColor: foreground.withValues(alpha: 0.70),
          shape: const StadiumBorder(),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MiniPlate extends StatelessWidget {
  const _MiniPlate({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = plate.trim().isEmpty ? '未填写车牌' : plate.trim().toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          color: palette.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) {
      return newValue;
    }
    final offset = newValue.selection.baseOffset.clamp(0, upper.length);
    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
