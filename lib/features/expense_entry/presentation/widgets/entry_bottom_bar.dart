import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';

class EntryBottomBar extends ConsumerWidget {
  const EntryBottomBar({super.key, required this.args, required this.onSave});

  final ExpenseEntryArgs args;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final state = ref.watch(expenseEntryControllerProvider(args));
    final enabled = state.canSave;
    final saving = state.isSaving;
    final uploading =
        saving &&
        state.totalReceipts > 0 &&
        state.uploadedReceipts < state.totalReceipts;
    final label = uploading
        ? '上传凭证 ${state.uploadedReceipts}/${state.totalReceipts}'
        : saving
        ? '保存中…'
        : args.mode == ExpenseEntryMode.edit
        ? '保存修改'
        : '保存并记入账本';
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.92),
        boxShadow: tokens.navShadow,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Semantics(
            button: true,
            enabled: enabled,
            label: label,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.primary, const Color(0xFF3FDFA5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.42),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: enabled ? onSave : null,
                    child: SizedBox(
                      height: ExpenseEntryStyle.buttonHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (saving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            Icon(
                              args.mode == ExpenseEntryMode.edit
                                  ? Icons.save_rounded
                                  : Icons.check_circle_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            maxLines: 1,
                            style: AppTypography.headlineSm.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
