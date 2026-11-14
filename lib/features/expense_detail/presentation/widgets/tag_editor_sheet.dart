import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/expense_detail_models.dart';

/// 标签编辑浮层：添加 / 移除标签，最多 8 个。
class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.initialTags,
    required this.onSave,
  });

  final List<String> initialTags;
  final Future<void> Function(List<String>) onSave;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final TextEditingController _controller;
  late List<String> _tags;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = sanitizeTags(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (_tags.length >= ExpenseDetailRules.maxTags) {
      setState(() => _error = '最多添加 ${ExpenseDetailRules.maxTags} 个标签');
      return;
    }
    if (value.runes.length > ExpenseDetailRules.maxTagLength) {
      setState(() => _error = '单个标签最多 ${ExpenseDetailRules.maxTagLength} 字');
      return;
    }
    final sanitized = sanitizeTags([value]);
    if (sanitized.isEmpty) {
      return;
    }
    final tag = sanitized.first;
    if (_tags.contains(tag)) {
      setState(() => _error = '标签已存在');
      return;
    }
    setState(() {
      _tags = [..._tags, tag];
      _controller.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_tags);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '添加标签',
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_tags.length}/${ExpenseDetailRules.maxTags}',
                    style: AppTypography.bodySm.copyWith(
                      color: palette.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#',
                      style: AppTypography.bodyLg.copyWith(
                        color: palette.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_saving,
                      maxLength: ExpenseDetailRules.maxTagLength,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTag(),
                      onChanged: (_) {
                        if (_error != null) {
                          setState(() => _error = null);
                        }
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '标签名，最多 10 字',
                        hintStyle: AppTypography.bodyMd.copyWith(
                          color: palette.outline,
                        ),
                        filled: true,
                        fillColor: palette.surfaceContainer.withValues(
                          alpha: 0.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: AppTypography.bodyMd.copyWith(
                        color: palette.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _addTag,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(64, 44),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_tags.isEmpty)
                Text(
                  '还没有标签，先加一个吧',
                  style: AppTypography.bodySm.copyWith(color: palette.outline),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      InputChip(
                        label: Text('#$tag'),
                        onDeleted: _saving
                            ? null
                            : () => setState(() {
                                _tags = [..._tags]..remove(tag);
                                _error = null;
                              }),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        backgroundColor: palette.surfaceContainer,
                        side: BorderSide.none,
                        labelStyle: AppTypography.labelMd.copyWith(
                          color: palette.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: AppTypography.bodySm.copyWith(color: palette.error),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
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
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
