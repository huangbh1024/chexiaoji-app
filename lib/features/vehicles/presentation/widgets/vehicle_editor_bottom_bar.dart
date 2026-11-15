import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/vehicle_editor_models.dart';
import '../vehicle_editor_style.dart';

class VehicleEditorBottomBar extends StatelessWidget {
  const VehicleEditorBottomBar({
    super.key,
    required this.state,
    required this.onSave,
    required this.onArchive,
  });

  final VehicleEditorState state;
  final VoidCallback onSave;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: palette.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            VehicleEditorStyle.bottomBarPadding,
            16,
            VehicleEditorStyle.bottomBarPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.formError != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      state.formError!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: palette.error,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(
                height: VehicleEditorStyle.saveButtonHeight,
                child: FilledButton(
                  onPressed: state.canSubmit ? onSave : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: palette.primary.withValues(
                      alpha: 0.45,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                state.mode == VehicleEditorMode.create
                                    ? '保存并添加到车库'
                                    : '更新并保存档案',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (state.mode == VehicleEditorMode.edit)
                SizedBox(
                  height: 40,
                  child: TextButton.icon(
                    onPressed: state.isSaving ? null : onArchive,
                    icon: Icon(
                      Icons.inventory_2_rounded,
                      size: 16,
                      color: state.isSaving ? palette.disabled : palette.error,
                    ),
                    label: Text(
                      '归档此车辆',
                      style: AppTypography.labelMd.copyWith(
                        color: state.isSaving
                            ? palette.disabled
                            : palette.error,
                      ),
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
