import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/toast.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/providers.dart';

class EntryHeader extends ConsumerWidget {
  const EntryHeader({super.key, required this.args, required this.onClose});

  final ExpenseEntryArgs args;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final isSaving = ref.watch(
      expenseEntryControllerProvider(args).select((state) => state.isSaving),
    );
    final title = args.mode == ExpenseEntryMode.edit ? '编辑这笔开销' : '记一笔开销';
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: palette.background.withValues(alpha: 0.86),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.close_rounded,
            label: '关闭',
            onTap: isSaving ? null : onClose,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
          ),
          _OcrCapsule(enabled: !isSaving),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Material(
            color: palette.surface,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  boxShadow: context.tokens.cardShadow,
                ),
                child: Icon(icon, size: 20, color: palette.onSurface),
              ),
            ),
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
      label: 'OCR识别',
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? () => showAppToast(context, 'OCR 识别将在下一版开放') : null,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(999),
              boxShadow: context.tokens.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 16,
                  color: palette.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'OCR识别',
                  style: AppTypography.labelMd.copyWith(
                    color: palette.primaryText,
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
