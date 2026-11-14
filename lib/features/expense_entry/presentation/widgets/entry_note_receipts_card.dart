import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/receipt_picker.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';

class EntryNoteReceiptsCard extends ConsumerStatefulWidget {
  const EntryNoteReceiptsCard({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  ConsumerState<EntryNoteReceiptsCard> createState() =>
      _EntryNoteReceiptsCardState();
}

class _EntryNoteReceiptsCardState extends ConsumerState<EntryNoteReceiptsCard> {
  late final TextEditingController _noteController;
  final _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final note = ref
        .read(expenseEntryControllerProvider(widget.args))
        .draft
        .note;
    _noteController = TextEditingController(text: note ?? '');
    _noteFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _syncNote(String? note) {
    if (_noteFocus.hasFocus) {
      return;
    }
    final text = note ?? '';
    if (_noteController.text != text) {
      _noteController.text = text;
    }
  }

  Future<void> _addReceipt() async {
    final source = await showModalBottomSheet<ReceiptSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReceiptSourceSheet(),
    );
    if (source == null || !mounted) {
      return;
    }
    try {
      final picked = await ref.read(receiptPickerProvider).pick(source);
      if (picked == null || !mounted) {
        return;
      }
      ref
          .read(expenseEntryControllerProvider(widget.args).notifier)
          .addReceipt(ReceiptAttachment(localPath: picked.path));
    } on ReceiptPermissionException catch (error) {
      if (mounted) {
        showAppToast(context, '${error.message}，请在系统设置中允许');
      }
    } on ReceiptTooLargeException catch (error) {
      if (mounted) {
        showAppToast(context, error.message);
      }
    } on ReceiptUnavailableException catch (error) {
      if (mounted) {
        showAppToast(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, '凭证选择失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(widget.args));
    final controller = ref.read(
      expenseEntryControllerProvider(widget.args).notifier,
    );
    ref.listen<String?>(
      expenseEntryControllerProvider(widget.args)
          .select((value) => value.draft.note),
      (previous, next) => _syncNote(next),
    );
    final receipts = state.draft.receipts
        .where((item) => !item.isDeleted)
        .toList(growable: false);
    final canAdd = receipts.length < 4;
    final slots = [
      ...receipts,
      if (canAdd) null,
      for (var i = receipts.length + (canAdd ? 1 : 0); i < 4; i++)
        const ReceiptAttachment(localPath: ''),
    ];
    final showCounter =
        _noteFocus.hasFocus || _noteController.text.characters.length > 150;

    return AppCard(
      radius: ExpenseEntryStyle.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '备注与凭证',
                style: AppTypography.bodyLg.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '选填 / 最多4张',
                style: AppTypography.labelSm.copyWith(
                  color: palette.outline,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              TextField(
                key: const Key('entry-note'),
                controller: _noteController,
                focusNode: _noteFocus,
                maxLength: 200,
                minLines: 1,
                maxLines: 3,
                style: AppTypography.bodyMd.copyWith(color: palette.onSurface),
                decoration: InputDecoration(
                  hintText: '添加备注（如：夜间谷电波段、停车减免券已核销）...',
                  hintStyle: AppTypography.bodyMd.copyWith(
                    color: palette.outlineVariant,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: palette.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (text) {
                  controller.setNote(text);
                  setState(() {});
                },
              ),
              if (showCounter)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Text(
                    '${_noteController.text.characters.length}/200',
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (final slot in slots)
                if (slot == null)
                  _AddReceiptSlot(onTap: _addReceipt)
                else if (slot.localPath.isEmpty)
                  const _EmptyReceiptSlot()
                else
                  _ReceiptThumb(
                    receipt: slot,
                    onDelete: () => controller.removeReceipt(slot),
                    onTap: () => _preview(slot),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  void _preview(ReceiptAttachment receipt) {
    final file = File(receipt.localPath);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      padding: const EdgeInsets.all(32),
                      color: context.palette.surface,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 40,
                        color: context.palette.outline,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReceiptThumb extends StatelessWidget {
  const _ReceiptThumb({
    required this.receipt,
    required this.onDelete,
    required this.onTap,
  });

  final ReceiptAttachment receipt;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Material(
            color: palette.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Image.file(
                File(receipt.localPath),
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, _, _) => Icon(
                  Icons.receipt_long_outlined,
                  size: 22,
                  color: palette.outline,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Semantics(
            button: true,
            label: '删除凭证',
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: palette.onSurface.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddReceiptSlot extends StatelessWidget {
  const _AddReceiptSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '添加凭证照片',
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRoundedRectPainter(
            color: palette.outlineVariant,
            radius: 16,
          ),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: palette.outline,
                ),
                const SizedBox(height: 2),
                Text(
                  '凭证照片',
                  style: AppTypography.labelSm.copyWith(
                    color: palette.outline,
                    fontWeight: FontWeight.w400,
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

class _EmptyReceiptSlot extends StatelessWidget {
  const _EmptyReceiptSlot();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 18,
          color: palette.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _ReceiptSourceSheet extends StatelessWidget {
  const _ReceiptSourceSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: palette.primary,
              ),
              title: Text(
                '拍照',
                style: AppTypography.bodyLg.copyWith(color: palette.onSurface),
              ),
              onTap: () => Navigator.of(context).pop(ReceiptSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: palette.tertiary,
              ),
              title: Text(
                '从相册选择',
                style: AppTypography.bodyLg.copyWith(color: palette.onSurface),
              ),
              onTap: () => Navigator.of(context).pop(ReceiptSource.gallery),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
