import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../vehicle_editor_style.dart';

InputDecoration editorInputDecoration(
  BuildContext context, {
  String? hint,
  String? suffixText,
}) {
  final palette = context.palette;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(VehicleEditorStyle.innerRadius),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint,
    suffixText: suffixText,
    hintStyle: AppTypography.bodyMd.copyWith(color: palette.outline),
    suffixStyle: AppTypography.labelSm.copyWith(color: palette.outline),
    filled: true,
    fillColor: palette.surfaceContainer.withValues(alpha: 0.7),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(Colors.transparent, 0),
    enabledBorder: border(Colors.transparent, 0),
    focusedBorder: border(palette.primary, 1.5),
    disabledBorder: border(Colors.transparent, 0),
  );
}

class EditorFieldLabel extends StatelessWidget {
  const EditorFieldLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(color: palette.onSurface),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EditorErrorText extends StatelessWidget {
  const EditorErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          message,
          style: AppTypography.bodySm.copyWith(color: context.palette.error),
        ),
      ),
    );
  }
}

class EditorHelperText extends StatelessWidget {
  const EditorHelperText(this.message, {super.key, this.icon, this.color});

  final String message;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = color ?? palette.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class EditorSectionCard extends StatelessWidget {
  const EditorSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      radius: VehicleEditorStyle.cardRadius,
      padding: const EdgeInsets.all(VehicleEditorStyle.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: VehicleEditorStyle.iconBox,
                height: VehicleEditorStyle.iconBox,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headlineSm.copyWith(
                        color: palette.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        color: palette.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: palette.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
