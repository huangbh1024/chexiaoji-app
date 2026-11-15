import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/vehicle_editor_presenter.dart';
import '../vehicle_editor_style.dart';
import 'vehicle_editor_field.dart';

class PlateInputFormatter extends TextInputFormatter {
  PlateInputFormatter({required this.green, required this.province});

  final bool green;
  final String province;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var body = VehicleEditorPresenter.normalizePlateBody(newValue.text);
    if (body.startsWith(province)) {
      body = body.substring(1);
    }
    final maxBody = VehicleEditorPresenter.plateBodyMaxLength(green);
    final limited = body.length > maxBody ? body.substring(0, maxBody) : body;
    final formatted = VehicleEditorPresenter.formatPlateBody(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class VehiclePlateInput extends StatelessWidget {
  const VehiclePlateInput({
    super.key,
    required this.controller,
    required this.province,
    required this.green,
    required this.onProvinceTap,
    required this.onGreenChanged,
    required this.onChanged,
    this.fieldKey,
    this.error,
    this.enabled = true,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String province;
  final bool green;
  final VoidCallback onProvinceTap;
  final ValueChanged<bool> onGreenChanged;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorFieldLabel(
          '车牌号码',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '新能源渐变绿牌',
                style: AppTypography.labelSm.copyWith(color: palette.outline),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 26,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch.adaptive(
                    value: green,
                    onChanged: enabled ? onGreenChanged : null,
                    activeTrackColor: palette.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Material(
              color: palette.surfaceContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(
                VehicleEditorStyle.innerRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('editor-province'),
                onTap: enabled ? onProvinceTap : null,
                child: SizedBox(
                  height: VehicleEditorStyle.inputHeight,
                  width: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        province,
                        style: AppTypography.headlineSm.copyWith(
                          color: palette.onSurface,
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: palette.outline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: fieldKey,
                    controller: controller,
                    enabled: enabled,
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                      letterSpacing: 1.4,
                    ),
                    inputFormatters: [
                      PlateInputFormatter(green: green, province: province),
                    ],
                    onChanged: onChanged,
                    decoration: editorInputDecoration(context),
                  ),
                  Container(
                    height: VehicleEditorStyle.plateStripHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: green
                            ? [
                                palette.primary,
                                palette.primary.withValues(alpha: 0.55),
                              ]
                            : const [Color(0xFF2563EB), Color(0xFF4F46E5)],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (error != null) EditorErrorText(error!),
      ],
    );
  }
}
