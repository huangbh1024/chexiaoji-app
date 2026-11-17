import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/payment_style.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../ledger/domain/ledger_models.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';

class EntryMetaCard extends ConsumerWidget {
  const EntryMetaCard({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(args));
    final controller = ref.read(expenseEntryControllerProvider(args).notifier);
    final place = state.draft.place;
    return AppCard(
      radius: ExpenseEntryStyle.cardRadius,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MetaRow(
            icon: Icons.schedule_rounded,
            iconColor: palette.outline,
            label: '发生时间',
            value: formatOccurredAtLabel(state.draft.occurredAt),
            onTap: () async {
              final time = await showModalBottomSheet<DateTime>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _TimeSheet(),
              );
              if (time != null) {
                controller.setOccurredAt(time);
              }
            },
          ),
          Divider(height: 1, color: palette.surfaceContainer),
          _MetaRow(
            icon: Icons.location_on_rounded,
            iconColor: palette.tertiary,
            label: '服务网点 / 地点',
            value: place ?? '未填写',
            muted: place == null,
            onTap: () async {
              final result = await showModalBottomSheet<_PlaceResult>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _PlaceSheet(
                  initial: place,
                  recent: [
                    ?state.defaults.lastPlace,
                    ...state.defaults.recentPlaces,
                  ],
                ),
              );
              if (result != null) {
                controller.setPlace(result.value);
              }
            },
          ),
          Divider(height: 1, color: palette.surfaceContainer),
          _MetaRow(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: palette.primary,
            label: '支付账户',
            value: state.draft.paymentLabel,
            leadingDot: state.draft.paymentChannel.color(palette),
            onTap: () async {
              final result = await showModalBottomSheet<_PaymentResult>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    _PaymentSheet(selectedLabel: state.draft.paymentLabel),
              );
              if (result != null) {
                controller.setPayment(result.channel, result.label);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.leadingDot,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;
  final Color? leadingDot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '$label，$value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppTypography.bodyMd.copyWith(
                    color: palette.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (leadingDot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: leadingDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      color: muted ? palette.outline : palette.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: palette.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSheet extends StatelessWidget {
  const _TimeSheet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final earlierToday = DateTime(now.year, now.month, now.day, 8);
    final yesterday = now.subtract(const Duration(days: 1));
    return _SheetShell(
      title: '发生时间',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetAction(
            icon: Icons.access_time_rounded,
            label: '现在',
            onTap: () => Navigator.of(context).pop(now),
          ),
          _SheetAction(
            icon: Icons.wb_twilight_rounded,
            label: '今天早些时候',
            onTap: () =>
                Navigator.of(context)
                    .pop(earlierToday.isAfter(now) ? now : earlierToday),
          ),
          _SheetAction(
            icon: Icons.history_rounded,
            label: '昨天',
            onTap: () => Navigator.of(context).pop(yesterday),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.tonal(
              onPressed: () async {
                final firstDate = DateTime(
                  now.year,
                  now.month - (ledgerHistoryMonths - 1),
                );
                final date = await showDatePicker(
                  context: context,
                  initialDate: now.isBefore(firstDate) ? firstDate : now,
                  firstDate: firstDate,
                  lastDate: DateTime(now.year, now.month, now.day),
                  helpText: '选择发生日期',
                );
                if (date == null || !context.mounted) {
                  return;
                }
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(now),
                  helpText: '选择发生时间',
                );
                if (time == null || !context.mounted) {
                  return;
                }
                Navigator.of(context).pop(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  ),
                );
              },
              child: Text(
                '选择日期与时间',
                style: AppTypography.bodyMd.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceResult {
  const _PlaceResult(this.value);

  final String? value;
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.initial, required this.recent});

  final String? initial;
  final List<String> recent;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final recent = widget.recent
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(3)
        .toList(growable: false);
    return _SheetShell(
      title: '服务网点 / 地点',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            maxLength: 30,
            autofocus: true,
            style: AppTypography.bodyLg.copyWith(color: palette.onSurface),
            decoration: InputDecoration(
              hintText: '选择或输入地点',
              counterText: '',
              filled: true,
              fillColor: palette.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '最近地点',
              style: AppTypography.labelSm.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in recent)
                  ActionChip(
                    label: Text(item),
                    onPressed: () {
                      _controller.text = item;
                      setState(() {});
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _PlaceResult(null)),
                child: const Text('清空'),
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _PlaceResult(
                      _controller.text.trim().isEmpty
                          ? null
                          : _controller.text.trim(),
                    ),
                  ),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentResult {
  const _PaymentResult(this.channel, this.label);

  final PaymentChannel channel;
  final String label;
}

class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({required this.selectedLabel});

  final String selectedLabel;

  static const _options = <(PaymentChannel, String)>[
    (PaymentChannel.wechat, '微信支付'),
    (PaymentChannel.wechat, '微信免密支付'),
    (PaymentChannel.alipay, '支付宝'),
    (PaymentChannel.unionpay, '云闪付'),
    (PaymentChannel.card, '银行卡'),
    (PaymentChannel.cash, '现金'),
    (PaymentChannel.other, '其他'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _SheetShell(
      title: '支付账户',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _options)
            Semantics(
              button: true,
              selected: option.$2 == selectedLabel,
              label: option.$2,
              child: Material(
                color: option.$2 == selectedLabel
                    ? palette.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context)
                          .pop(_PaymentResult(option.$1, option.$2)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: option.$1.color(palette),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          option.$2,
                          style: AppTypography.bodyLg.copyWith(
                            color: palette.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (option.$2 == selectedLabel)
                          Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: palette.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: palette.outline,
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, size: 20, color: palette.outline),
      title: Text(
        label,
        style: AppTypography.bodyLg.copyWith(color: palette.onSurface),
      ),
      onTap: onTap,
    );
  }
}
