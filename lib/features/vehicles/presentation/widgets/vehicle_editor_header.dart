import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/toast.dart';
import '../../domain/vehicle_editor_models.dart';
import '../../domain/vehicle_editor_presenter.dart';

class VehicleEditorHeader extends StatelessWidget {
  const VehicleEditorHeader({
    super.key,
    required this.state,
    required this.onBack,
  });

  final VehicleEditorState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final subtitle = VehicleEditorPresenter.subtitleOf(state);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SizedBox(
        height: tokens.headerHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: '返回',
                child: Material(
                  color: palette.surface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: state.isSaving ? null : onBack,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: state.isSaving
                            ? palette.disabled
                            : palette.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      VehicleEditorPresenter.titleOf(state.mode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd.copyWith(
                        color: palette.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSm.copyWith(
                        color: state.isDirty
                            ? palette.primaryText
                            : palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _OcrCapsule(enabled: !state.isSaving),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcrCapsule extends StatelessWidget {
  const _OcrCapsule({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '证件识别，即将上线',
      child: Material(
        color: palette.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.tokens.radiusPill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => showAppToast(context, '证件识别将在下一版开放') : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 16,
                  color: enabled ? palette.primaryText : palette.disabled,
                ),
                const SizedBox(width: 4),
                Text(
                  '证件识别',
                  style: AppTypography.labelSm.copyWith(
                    color: enabled ? palette.primaryText : palette.disabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
