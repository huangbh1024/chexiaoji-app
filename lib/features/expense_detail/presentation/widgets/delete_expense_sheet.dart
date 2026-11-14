import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// 删除确认浮层。成功后返回 true。
class DeleteExpenseSheet extends StatefulWidget {
  const DeleteExpenseSheet({super.key, required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<DeleteExpenseSheet> createState() => _DeleteExpenseSheetState();
}

class _DeleteExpenseSheetState extends State<DeleteExpenseSheet> {
  bool _deleting = false;

  Future<void> _confirm() async {
    if (_deleting) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('删除失败，请重试'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '删除这笔开销？',
              style: AppTypography.headlineSm.copyWith(color: palette.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              '删除后无法恢复，月度汇总、账单列表与报表会同步更新。',
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurfaceVariant,
                height: 20 / 13,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _deleting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      '取消',
                      style: AppTypography.labelLg.copyWith(
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _deleting ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('删除'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
