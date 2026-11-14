import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/expense_detail_models.dart';
import '../../domain/expense_detail_presenter.dart';
import '../expense_detail_style.dart';

/// 标签与用车备注卡。
class DetailTagsNoteCard extends StatelessWidget {
  const DetailTagsNoteCard({
    super.key,
    required this.detail,
    required this.onEditNote,
    required this.onAddTag,
    required this.onRemoveTag,
    this.isSyncing = false,
  });

  final ExpenseDetail detail;
  final VoidCallback onEditNote;
  final VoidCallback onAddTag;
  final ValueChanged<String> onRemoveTag;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Opacity(
      opacity: isSyncing ? 0.6 : 1,
      child: IgnorePointer(
        ignoring: isSyncing,
        child: AppCard(
          radius: ExpenseDetailStyle.cardRadius,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.label_rounded,
                    size: 18,
                    color: palette.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '标签与用车备注',
                    style: AppTypography.labelLg.copyWith(
                      color: palette.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _EditNoteButton(onTap: onEditNote),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in detail.tags)
                    _TagPill(
                      tag: tag,
                      onTap: () => onRemoveTag(tag),
                    ),
                  _AddTagPill(onTap: onAddTag),
                ],
              ),
              const SizedBox(height: 12),
              _NoteBlock(
                note: detail.noteText,
                onEdit: onEditNote,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditNoteButton extends StatelessWidget {
  const _EditNoteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '编辑备注',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 14, color: palette.tertiary),
              const SizedBox(width: 2),
              Text(
                '编辑备注',
                style: AppTypography.labelMd.copyWith(
                  color: palette.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.onTap});

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '标签 $tag',
      child: Material(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              '#$tag',
              style: AppTypography.labelMd.copyWith(
                color: palette.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTagPill extends StatelessWidget {
  const _AddTagPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '添加标签',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: palette.outlineVariant),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 13, color: palette.outline),
                const SizedBox(width: 2),
                Text(
                  '添加标签',
                  style: AppTypography.labelMd.copyWith(
                    color: palette.outline,
                    fontWeight: FontWeight.w600,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(999),
        ),
      );
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NoteBlock extends StatefulWidget {
  const _NoteBlock({required this.note, required this.onEdit});

  final String note;
  final VoidCallback onEdit;

  @override
  State<_NoteBlock> createState() => _NoteBlockState();
}

class _NoteBlockState extends State<_NoteBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasNote = widget.note.trim().isNotEmpty;
    final style = AppTypography.bodyMd.copyWith(
      color: palette.onSurfaceVariant,
      height: 20 / 13,
    );
    return GestureDetector(
      onTap: hasNote ? null : widget.onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 18,
              color: palette.outlineVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: hasNote
                  ? _NoteText(
                      note: widget.note,
                      style: style,
                      expanded: _expanded,
                      onToggle: () => setState(() => _expanded = !_expanded),
                    )
                  : Text(
                      '写点什么，方便以后回想这笔开销',
                      style: style.copyWith(color: palette.outline),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteText extends StatelessWidget {
  const _NoteText({
    required this.note,
    required this.style,
    required this.expanded,
    required this.onToggle,
  });

  final String note;
  final TextStyle style;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = '“$note”';
    final style = this.style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 4,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: style,
              maxLines: expanded ? null : 4,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (canExpand)
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    expanded ? '收起' : '展开',
                    style: AppTypography.labelMd.copyWith(
                      color: palette.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
