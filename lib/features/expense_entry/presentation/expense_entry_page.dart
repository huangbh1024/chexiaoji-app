import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/presentation/toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_error.dart';
import '../data/expense_entry_repository.dart';
import '../domain/expense_entry_models.dart';
import '../domain/providers.dart';
import 'widgets/entry_amount_card.dart';
import 'widgets/entry_bottom_bar.dart';
import 'widgets/entry_category_chips.dart';
import 'widgets/entry_header.dart';
import 'widgets/entry_meta_card.dart';
import 'widgets/entry_mileage_card.dart';
import 'widgets/entry_note_receipts_card.dart';
import 'widgets/entry_params_card.dart';
import 'widgets/entry_vehicle_card.dart';

class ExpenseEntryPage extends ConsumerStatefulWidget {
  const ExpenseEntryPage({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  ConsumerState<ExpenseEntryPage> createState() => _ExpenseEntryPageState();
}

class _ExpenseEntryPageState extends ConsumerState<ExpenseEntryPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ExpenseEntryState get _state =>
      ref.read(expenseEntryControllerProvider(widget.args));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(widget.args));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  EntryHeader(args: widget.args, onClose: _handleClose),
                  Expanded(child: _body(state)),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: EntryBottomBar(
          args: widget.args,
          onSave: _handleSave,
        ),
      ),
    );
  }

  Widget _body(ExpenseEntryState state) {
    if (state.hasNoVehicles) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          EmptyState(
            icon: Icons.directions_car_outlined,
            title: '先添加一辆车，才能开始记账',
            actionLabel: '去添加',
            onAction: () => showAppToast(context, '车辆管理待接入'),
          ),
        ],
      );
    }

    if (state.vehicle == null && !state.isLoadingDefaults) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionError(
            message: '记账页加载失败',
            onRetry: () =>
                ref.invalidate(expenseEntryControllerProvider(widget.args)),
          ),
        ],
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              EntryVehicleCard(args: widget.args),
              if (state.defaultsError != null) ...[
                const SizedBox(height: 8),
                _DefaultsWarning(
                  onRetry: () => ref
                      .read(
                        expenseEntryControllerProvider(widget.args).notifier,
                      )
                      .retryDefaults(),
                ),
              ],
              const SizedBox(height: 20),
              EntryCategoryChips(args: widget.args),
              const SizedBox(height: 12),
              EntryAmountCard(args: widget.args),
              const SizedBox(height: 20),
              EntryParamsCard(args: widget.args),
              const SizedBox(height: 20),
              EntryMileageCard(args: widget.args),
              const SizedBox(height: 20),
              EntryMetaCard(args: widget.args),
              const SizedBox(height: 20),
              EntryNoteReceiptsCard(args: widget.args),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(
      expenseEntryControllerProvider(widget.args).notifier,
    );
    ExpenseEntryResult? result;
    try {
      result = await controller.save();
    } on ExpenseEntryConflictException {
      if (!mounted) {
        return;
      }
      showAppToast(context, '这笔记账已在其他设备更新，请重新载入');
      return;
    }
    if (!mounted) {
      return;
    }
    if (result is ExpenseEntrySaved) {
      _finishSave(result);
      return;
    }
    final state = _state;
    if (state.validation.needsOdometerConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('里程跨度较大，确认读数无误？'),
          content: Text(
            '本次读数与上次相差 ${_formatDelta(state.draft.distanceKm)}，'
            '请确认是否输入正确。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认保存'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        try {
          final forced = await controller.save(forceOdometer: true);
          if (forced is ExpenseEntrySaved && mounted) {
            _finishSave(forced);
          } else if (mounted) {
            showAppToast(context, '保存失败，请重试');
          }
        } on ExpenseEntryConflictException {
          if (mounted) {
            showAppToast(context, '这笔记账已在其他设备更新，请重新载入');
          }
        }
      }
      return;
    }
    if (state.validation.message != null) {
      showAppToast(context, state.validation.message!);
      return;
    }
    if (state.saveError != null) {
      showAppToast(context, '保存失败，请重试');
    }
  }

  void _finishSave(ExpenseEntrySaved result) {
    showAppToast(
      context,
      widget.args.mode == ExpenseEntryMode.create ? '已记入账本' : '修改已保存',
    );
    Navigator.of(context).pop(result);
  }

  Future<void> _handleClose() async {
    if (_state.isSaving) {
      return;
    }
    if (!_state.hasUnsavedChanges) {
      Navigator.of(context).pop(const ExpenseEntryCancelled());
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.args.mode == ExpenseEntryMode.create ? '放弃这笔记录？' : '放弃修改？',
        ),
        content: Text(
          widget.args.mode == ExpenseEntryMode.create
              ? '已填写的内容不会保存。'
              : '本次修改不会保存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop(const ExpenseEntryCancelled());
    }
  }

  String _formatDelta(int? delta) {
    if (delta == null) {
      return '—';
    }
    return '${delta.abs()} km';
  }
}

class _DefaultsWarning extends StatelessWidget {
  const _DefaultsWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: palette.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '默认值加载失败，已使用本地默认值',
            style: TextStyle(fontSize: 10, color: palette.outline),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('重试', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}
