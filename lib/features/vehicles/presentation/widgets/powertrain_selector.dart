import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/presentation/category_style.dart';
import '../../domain/vehicle_editor_presenter.dart';

const _powertrainOrder = <PowertrainType>[
  PowertrainType.ev,
  PowertrainType.phev,
  PowertrainType.hev,
  PowertrainType.ice,
];

class PowertrainSelector extends StatelessWidget {
  const PowertrainSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PowertrainType value;
  final ValueChanged<PowertrainType> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: palette.primary),
              const SizedBox(width: 6),
              Text(
                '动力类型',
                style: AppTypography.labelLg.copyWith(color: palette.onSurface),
              ),
              const Spacer(),
              Text(
                '决定核算口径',
                style: AppTypography.labelSm.copyWith(color: palette.outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: palette.surfaceContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: palette.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              for (var index = 0; index < _powertrainOrder.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: _PowertrainSegment(
                    type: _powertrainOrder[index],
                    selected: _powertrainOrder[index] == value,
                    enabled: enabled,
                    onTap: () => onChanged(_powertrainOrder[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PowertrainSegment extends StatelessWidget {
  const _PowertrainSegment({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PowertrainType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = type.color;
    final label = switch (type) {
      PowertrainType.ev => '纯电 EV',
      PowertrainType.phev => '插混·增程',
      PowertrainType.hev => '油电混动',
      PowertrainType.ice => '燃油 ICE',
    };
    final sublabel = VehicleEditorPresenter.powertrainSublabel(type);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label，$sublabel',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? palette.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.24)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (type) {
                    PowertrainType.ev => Icons.electric_car_rounded,
                    PowertrainType.phev => Icons.ev_station_rounded,
                    _ => Icons.local_gas_station_rounded,
                  },
                  size: 22,
                  color: selected ? accent : palette.outline,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMd.copyWith(
                    color: selected ? palette.onSurface : palette.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    color: selected ? accent : palette.outline,
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
