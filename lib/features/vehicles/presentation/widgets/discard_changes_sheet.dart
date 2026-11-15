import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import 'vehicle_sheet_shell.dart';

Future<bool?> showDiscardChangesSheet(BuildContext context) {
  return showVehicleSheet<bool>(context, (_) => const _DiscardSheet());
}

class _DiscardSheet extends StatelessWidget {
  const _DiscardSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.secondary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 26,
              color: palette.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '放弃未保存的修改？',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          '当前填写的内容尚未保存，离开后将丢失。',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: palette.outline,
            height: 20 / 13,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SheetActionButton(
                label: '继续编辑',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SheetActionButton(
                label: '放弃修改',
                icon: Icons.close_rounded,
                backgroundColor: palette.error,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
