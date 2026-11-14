import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../ledger/domain/ledger_models.dart';
import '../data/expense_detail_repository.dart';
import '../domain/expense_detail_models.dart';
import '../domain/expense_detail_presenter.dart';
import '../domain/providers.dart';
import 'widgets/delete_expense_sheet.dart';
import 'widgets/detail_bottom_bar.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_hero_card.dart';
import 'widgets/detail_more_sheet.dart';
import 'widgets/detail_settlement_card.dart';
import 'widgets/detail_tags_note_card.dart';
import 'widgets/detail_vehicle_card.dart';
import 'widgets/note_editor_sheet.dart';
import 'widgets/tag_editor_sheet.dart';

/// 单笔开销详情页。由账单记录卡推入，返回时携带 [ExpenseDetailOutcome]。
class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({
    super.key,
    required this.recordId,
    this.initialRecord,
  });

  final String recordId;
  final LedgerRecord? initialRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final topInset = MediaQuery.paddingOf(context).top;
    final asyncDetail = ref.watch(expenseDetailProvider(recordId));
    final notFound = asyncDetail.error is ExpenseNotFoundException;
    final snapshot = initialRecord == null
        ? null
        : ExpenseDetail.fromRecord(initialRecord!);
    final detail = notFound ? null : (asyncDetail.value ?? snapshot);
    final hasLoadError =
        asyncDetail.hasError && !notFound && asyncDetail.value == null;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const _AmbientBackdrop(),
                    CustomScrollView(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: BlurredHeaderDelegate(
                            height: 56 + topInset,
                            child: DetailHeader(
                              topInset: topInset,
                              enabled: detail != null,
                              onBack: () => Navigator.of(context).maybePop(),
                              onShare: detail == null
                                  ? null
                                  : () => _share(context, detail),
                              onMore: detail == null
                                  ? null
                                  : () => _showMore(context, ref, detail),
                            ),
                          ),
                        ),
                        if (detail == null && notFound)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: EmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: '这笔记录不存在或已被删除',
                                actionLabel: '返回账单',
                                onAction: () => Navigator.of(context).pop(),
                              ),
                            ),
                          )
                        else if (detail == null && hasLoadError)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SectionError(
                                message: '加载失败',
                                onRetry: () => ref.invalidate(
                                  expenseDetailProvider(recordId),
                                ),
                              ),
                            ),
                          )
                        else if (detail == null)
                          const SliverPadding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                            sliver: SliverToBoxAdapter(child: _DetailSkeleton()),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                if (asyncDetail.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SectionError(
                                      message: '部分信息加载失败',
                                      onRetry: () => ref.invalidate(
                                        expenseDetailProvider(recordId),
                                      ),
                                    ),
                                  ),
                                DetailHeroCard(detail: detail),
                                const SizedBox(height: 12),
                                DetailVehicleCard(
                                  detail: detail,
                                  onTap: detail.vehicleBound
                                      ? () => _toast(context, '车辆管理待接入')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                DetailSettlementCard(
                                  detail: detail,
                                  isSyncing: asyncDetail.isLoading,
                                ),
                                const SizedBox(height: 12),
                                DetailTagsNoteCard(
                                  detail: detail,
                                  isSyncing: asyncDetail.isLoading,
                                  onEditNote: () =>
                                      _editNote(context, ref, detail),
                                  onAddTag: () => _editTags(context, ref, detail),
                                  onRemoveTag: (tag) =>
                                      _removeTag(context, ref, detail, tag),
                                ),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              DetailBottomBar(
                enabled: detail != null,
                onReAdd: () => _toast(context, '记账页待接入'),
                onEdit: () => _toast(context, '记账页待接入'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, ExpenseDetail detail) async {
    try {
      await SharePlus.instance.share(ShareParams(text: detail.shareText));
    } catch (_) {
      if (context.mounted) {
        _toast(context, '分享失败，请重试');
      }
    }
  }

  Future<void> _copy(BuildContext context, ExpenseDetail detail) async {
    await Clipboard.setData(ClipboardData(text: detail.shareText));
    if (context.mounted) {
      _toast(context, '已复制');
    }
  }

  void _showMore(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DetailMoreSheet(
        onCopy: () => _copy(context, detail),
        onDelete: () => _delete(context, ref),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DeleteExpenseSheet(
        onConfirm: () =>
            ref.read(expenseDetailProvider(recordId).notifier).delete(),
      ),
    );
    if (deleted == true && context.mounted) {
      Navigator.of(context).pop(ExpenseDetailOutcome.deleted);
    }
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => NoteEditorSheet(
        initialNote: detail.noteText,
        onSave: (note) =>
            ref.read(expenseDetailProvider(recordId).notifier).saveNote(note),
      ),
    );
    if (saved == true && context.mounted) {
      _toast(context, '备注已保存');
    }
  }

  Future<void> _editTags(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => TagEditorSheet(
        initialTags: detail.tags,
        onSave: (tags) =>
            ref.read(expenseDetailProvider(recordId).notifier).saveTags(tags),
      ),
    );
    if (saved == true && context.mounted) {
      _toast(context, '标签已更新');
    }
  }

  Future<void> _removeTag(
    BuildContext context,
    WidgetRef ref,
    ExpenseDetail detail,
    String tag,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '#$tag',
                    style: AppTypography.headlineSm.copyWith(
                      color: sheetContext.palette.onSurface,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.close_rounded,
                  color: sheetContext.palette.error,
                ),
                title: Text(
                  '移除标签',
                  style: AppTypography.bodyLg.copyWith(
                    color: sheetContext.palette.error,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              ListTile(
                title: Text(
                  '取消',
                  style: AppTypography.bodyLg.copyWith(
                    color: sheetContext.palette.onSurfaceVariant,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final tags = detail.tags.where((item) => item != tag).toList();
      await ref.read(expenseDetailProvider(recordId).notifier).saveTags(tags);
      if (context.mounted) {
        _toast(context, '标签已更新');
      }
    } catch (_) {
      if (context.mounted) {
        _toast(context, '保存失败，请重试');
      }
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 384,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.surfaceContainer,
                      palette.background,
                      palette.background,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -48,
              top: -48,
              child: _Glow(
                size: 256,
                color: palette.primary.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              right: -40,
              top: 112,
              child: _Glow(
                size: 288,
                color: palette.tertiary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SkeletonBox(width: 56, height: 56, radius: 16),
              const SizedBox(height: 12),
              const SkeletonBox(width: 140, height: 18, radius: 6),
              const SizedBox(height: 6),
              const SkeletonBox(width: 72, height: 12, radius: 6),
              const SizedBox(height: 20),
              const SkeletonBox(width: 160, height: 38, radius: 8),
              const SizedBox(height: 8),
              const SkeletonBox(width: 190, height: 12, radius: 6),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < 3; index++) ...[
          AppCard(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonBox(width: 18, height: 18, radius: 6),
                    const SizedBox(width: 8),
                    const SkeletonBox(width: 100, height: 14, radius: 6),
                    const Spacer(),
                    const SkeletonBox(width: 52, height: 14, radius: 6),
                  ],
                ),
                const SizedBox(height: 14),
                const SkeletonBox(height: 56, radius: 14),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
