import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/expense_entry_models.dart';
import '../../domain/expense_entry_presenter.dart';
import '../../domain/providers.dart';
import '../expense_entry_style.dart';
import 'entry_telemetry_pill.dart';

class EntryAmountCard extends ConsumerStatefulWidget {
  const EntryAmountCard({super.key, required this.args});

  final ExpenseEntryArgs args;

  @override
  ConsumerState<EntryAmountCard> createState() => _EntryAmountCardState();
}

class _EntryAmountCardState extends ConsumerState<EntryAmountCard> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final amount = ref
        .read(expenseEntryControllerProvider(widget.args))
        .draft
        .amountCents;
    _controller = TextEditingController(
      text: amount > 0 ? formatYuanInput(amount) : '',
    );
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      return;
    }
    final cents = parseYuanToCents(_controller.text) ?? 0;
    final text = cents > 0 ? formatYuanInput(cents) : '';
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    setState(() {});
  }

  void _syncAmount(int cents) {
    if (parseYuanToCents(_controller.text) == cents) {
      return;
    }
    final text = cents <= 0 ? '' : formatYuanInput(cents);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(expenseEntryControllerProvider(widget.args));
    final controller = ref.read(
      expenseEntryControllerProvider(widget.args).notifier,
    );
    ref.listen<int>(
      expenseEntryControllerProvider(widget.args)
          .select((value) => value.draft.amountCents),
      (previous, next) => _syncAmount(next),
    );
    final presets = presetsFor(
      draft: state.draft,
      batteryCapacityKwh: state.defaults.batteryCapacityKwh,
      tankCapacityL: state.defaults.tankCapacityL,
    );

    return AppCard(
      radius: ExpenseEntryStyle.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -40,
            width: 176,
            height: 176,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.primary.withValues(alpha: 0.16),
                      palette.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '实付金额 (元)',
                style: AppTypography.labelMd.copyWith(color: palette.outline),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '¥',
                      style: AppTypography.headlineMd.copyWith(
                        color: palette.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      key: const Key('entry-amount'),
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [AmountInputFormatter()],
                      style: AppTypography.displayHero.copyWith(
                        color: palette.onSurface,
                      ),
                      cursorWidth: 2,
                      cursorHeight: 28,
                      cursorColor: palette.primary,
                      decoration: InputDecoration.collapsed(
                        hintText: '0.00',
                        hintStyle: AppTypography.displayHero.copyWith(
                          color: palette.outlineVariant,
                        ),
                      ),
                      onChanged: (text) {
                        final cents = parseYuanToCents(text) ?? 0;
                        controller.setAmountCents(cents);
                      },
                    ),
                  ),
                  if (state.draft.amountCents > 0)
                    Semantics(
                      button: true,
                      label: '清空输入',
                      child: IconButton(
                        onPressed: () {
                          _controller.clear();
                          controller.setAmountCents(0);
                        },
                        icon: Icon(
                          Icons.backspace_outlined,
                          size: 16,
                          color: palette.outline,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: palette.surfaceContainer,
                          minimumSize: const Size(28, 28),
                          fixedSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.only(top: 8),
                color: palette.surfaceContainer,
              ),
              const SizedBox(height: 12),
              EntryTelemetryPill(args: widget.args),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _PresetChip(
                        preset: presets[i],
                        selected:
                            state.draft.amountCents ==
                            presetAmountCents(
                              presets[i],
                              draft: state.draft,
                              batteryCapacityKwh:
                                  state.defaults.batteryCapacityKwh,
                              tankCapacityL: state.defaults.tankCapacityL,
                            ),
                        onTap: () {
                          controller.applyPreset(presets[i]);
                          if (presets[i].kind == EntryPresetKind.full &&
                              state.draft.category == ExpenseCategory.fuel) {
                            showAppToast(context, '已按油箱容量估算，请按实际金额调整');
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final EntryPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: preset.displayLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? palette.primary.withValues(alpha: 0.1)
                  : palette.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
              border: selected
                  ? Border.all(color: palette.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Text(
              preset.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                color: selected ? palette.primaryText : palette.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AmountInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^(?:\d{0,6})(?:\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.startsWith('.')) {
      text = '0$text';
    }
    if (text == newValue.text && (text.isEmpty || _pattern.hasMatch(text))) {
      return newValue;
    }
    if (text.isEmpty || _pattern.hasMatch(text)) {
      return newValue.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return oldValue;
  }
}
