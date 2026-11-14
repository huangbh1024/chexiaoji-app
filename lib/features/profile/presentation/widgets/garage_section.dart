import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/vehicle.dart';
import '../../../../core/presentation/category_style.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_error.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../home/domain/providers.dart';
import '../../domain/garage_aggregation.dart';
import '../../domain/profile_presenter.dart';
import '../../domain/providers.dart';
import '../profile_style.dart';
import 'garage_vehicle_card.dart';

class GarageSection extends ConsumerWidget {
  const GarageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(profileGarageVehicleIdProvider);
    final vehicles = vehiclesAsync.value;
    final effectiveId =
        vehicles != null &&
            selectedId != null &&
            !vehicles.any((vehicle) => vehicle.id == selectedId)
        ? null
        : selectedId;

    if (vehicles != null && effectiveId != selectedId) {
      final currentContext = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!currentContext.mounted) {
          return;
        }
        ref.read(profileGarageVehicleIdProvider.notifier).select(null);
      });
    }

    final garageAsync = ref.watch(profileGarageProvider(effectiveId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '车库资产与车辆',
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: '管理爱车',
              child: InkWell(
                key: const Key('garage-manage'),
                onTap: () => showAppToast(context, '车辆管理页待接入'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '管理爱车',
                        style: AppTypography.labelMd.copyWith(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: palette.primaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ProfileStyle.cardGap),
        if (vehiclesAsync.hasError && !vehiclesAsync.hasValue)
          SectionError(
            message: '车辆加载失败',
            onRetry: () => ref.invalidate(vehiclesProvider),
          )
        else ...[
          vehiclesAsync.when(
            skipError: true,
            loading: () => const _PillSkeleton(),
            error: (error, stack) => SectionError(
              message: '车辆加载失败',
              onRetry: () => ref.invalidate(vehiclesProvider),
            ),
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : _PillRow(
                    vehicles: items,
                    selectedId: effectiveId,
                    onSelect: (vehicleId) => ref
                        .read(profileGarageVehicleIdProvider.notifier)
                        .select(vehicleId),
                  ),
          ),
          const SizedBox(height: ProfileStyle.cardGap),
          vehiclesAsync.when(
            skipError: true,
            loading: () => const _GarageCardSkeleton(),
            error: (error, stack) => SectionError(
              message: '车辆加载失败',
              onRetry: () => ref.invalidate(vehiclesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.garage_rounded,
                  title: '还没有添加车辆',
                  actionLabel: '添加车辆',
                  onAction: () => showAppToast(context, '添加车辆页待接入'),
                );
              }
              if (garageAsync.hasError && !garageAsync.hasValue) {
                return SectionError(
                  message: '车辆数据加载失败',
                  onRetry: () =>
                      ref.invalidate(profileGarageProvider(effectiveId)),
                );
              }
              return garageAsync.when(
                skipError: true,
                loading: () => const _GarageCardSkeleton(),
                error: (error, stack) => SectionError(
                  message: '车辆数据加载失败',
                  onRetry: () =>
                      ref.invalidate(profileGarageProvider(effectiveId)),
                ),
                data: (garage) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: GarageVehicleCard(
                    key: ValueKey<String>(effectiveId ?? 'all'),
                    view: buildGarageCardView(garage.snapshot),
                    snapshot: garage.snapshot,
                    onAdd: () => showAppToast(context, '添加车辆页待接入'),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProfileStyle.pillHeight + 10,
      child: ListView.separated(
        key: const Key('garage-pills'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 5),
        itemCount: vehicles.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GaragePill(
              key: const Key('garage-pill-all'),
              label: '全部资产',
              count: vehicles.length,
              selected: selectedId == null,
              onTap: () => onSelect(null),
            );
          }
          final vehicle = vehicles[index - 1];
          return _GaragePill(
            key: Key('garage-pill-${vehicle.id}'),
            label: '${shortNameFor(vehicle.name)} · ${vehicle.powertrainLabel}',
            dotColor: vehicle.powertrain.color,
            selected: selectedId == vehicle.id,
            onTap: () => onSelect(vehicle.id),
          );
        },
      ),
    );
  }
}

class _GaragePill extends StatelessWidget {
  const _GaragePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final foreground = selected ? palette.surface : palette.outline;

    return Material(
      color: selected ? palette.onSurface : palette.surface,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: ProfileStyle.pillMaxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            border: Border.all(
              color: selected ? Colors.transparent : palette.surfaceContainer,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.surface.withValues(alpha: 0.18)
                        : palette.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: AppTypography.labelSm.copyWith(
                      color: selected ? palette.surface : palette.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PillSkeleton extends StatelessWidget {
  const _PillSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: ProfileStyle.pillHeight + 10,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SkeletonBox(width: 96, height: 34, radius: 17),
            SizedBox(width: 8),
            SkeletonBox(width: 112, height: 34, radius: 17),
            SizedBox(width: 8),
            SkeletonBox(width: 88, height: 34, radius: 17),
          ],
        ),
      ),
    );
  }
}

class _GarageCardSkeleton extends StatelessWidget {
  const _GarageCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 80, height: 16),
          SizedBox(height: 10),
          SkeletonBox(width: 170, height: 18),
          SizedBox(height: 6),
          SkeletonBox(width: 130, height: 12),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 58, radius: 8)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 58, radius: 8)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 58, radius: 8)),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(width: 220, height: 14),
        ],
      ),
    );
  }
}
