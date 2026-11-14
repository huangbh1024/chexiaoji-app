import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/format/formatters.dart';
import '../../domain/home_models.dart';
import '../../domain/providers.dart';
import '../home_style.dart';

class VehicleSwitcher extends ConsumerStatefulWidget {
  const VehicleSwitcher({super.key});

  @override
  ConsumerState<VehicleSwitcher> createState() => _VehicleSwitcherState();
}

class _VehicleSwitcherState extends ConsumerState<VehicleSwitcher> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'vehicle-$id'));

  void _select(Vehicle vehicle) {
    ref.read(selectedVehicleIdProvider.notifier).select(vehicle.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardContext = _keyFor(vehicle.id).currentContext;
      if (cardContext == null || !cardContext.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        cardContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(selectedVehicleIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '我的车辆',
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            const SizedBox(
              width: 24,
              height: 8,
              child: CustomPaint(painter: _WaveLinePainter()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: vehiclesAsync.maybeWhen(
                  data: (vehicles) => _Indicator(
                    count: vehicles.length,
                    selectedIndex: vehicles.indexWhere(
                      (vehicle) => vehicle.id == selectedId,
                    ),
                  ),
                  orElse: () => const _Indicator(count: 3, selectedIndex: 0),
                ),
              ),
            ),
            _ManageButton(onTap: () => _toast(context, '车辆管理页待接入')),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        SizedBox(
          height: 140,
          child: Stack(
            children: [
              Positioned.fill(
                child: vehiclesAsync.when(
                  data: (vehicles) => ListView.separated(
                    key: const Key('vehicle-list'),
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: vehicles.length + 1,
                    separatorBuilder: (_, _) => SizedBox(width: tokens.gutter),
                    itemBuilder: (context, index) {
                      if (index == vehicles.length) {
                        return _AddVehicleCard(
                          onTap: () => _toast(context, '添加车辆页待接入'),
                        );
                      }
                      final vehicle = vehicles[index];
                      return VehicleCard(
                        key: _keyFor(vehicle.id),
                        vehicle: vehicle,
                        selected: vehicle.id == selectedId,
                        onTap: () => _select(vehicle),
                      );
                    },
                  ),
                  loading: () => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: 4,
                    separatorBuilder: (_, _) => SizedBox(width: tokens.gutter),
                    itemBuilder: (context, index) => index == 3
                        ? const SkeletonVehicleCard(width: 80)
                        : const SkeletonVehicleCard(width: 192),
                  ),
                  error: (error, stack) => Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(vehiclesProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('车辆加载失败，点击重试'),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          palette.background.withValues(alpha: 0),
                          palette.background,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

class _Indicator extends StatelessWidget {
  const _Indicator({required this.count, required this.selectedIndex});

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: palette.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < count; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: index == selectedIndex ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: index == selectedIndex
                    ? palette.primary
                    : palette.outlineVariant.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: palette.surfaceContainer,
          borderRadius: BorderRadius.circular(tokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '管理车辆',
              style: AppTypography.labelMd.copyWith(color: palette.primaryText),
            ),
            const SizedBox(width: 2),
            Icon(Icons.tune_rounded, size: 14, color: palette.primaryText),
          ],
        ),
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final color = vehicle.powertrain.color;
    final pillTextColor = switch (vehicle.powertrain) {
      PowertrainType.ev => palette.primaryText,
      PowertrainType.hev => palette.secondaryText,
      PowertrainType.phev => palette.tertiary,
      PowertrainType.ice => palette.onSurfaceVariant,
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: selected ? 1 : 0.86,
      child: SizedBox(
        width: 192,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              border: Border.all(
                color: selected
                    ? palette.primary
                    : palette.outlineVariant.withValues(alpha: 0.6),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? tokens.selectedShadow : tokens.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusCard - 2),
              child: Stack(
                children: [
                  Positioned(
                    right: -28,
                    bottom: -28,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              vehicle.powertrain.icon,
                              size: 16,
                              color: color,
                            ),
                          ),
                          const Spacer(),
                          if (selected)
                            _SelectedBadge(color: palette.primary)
                          else if (vehicle.badge != null)
                            _BadgeTag(
                              text: vehicle.badge!,
                              color: color,
                              textColor: pillTextColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        vehicle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          color: palette.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicle.plate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(
                            tokens.radiusChip,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${vehicle.powertrainLabel} · ${formatKm(vehicle.odometerKm)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: pillTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
    );
  }
}

class _BadgeTag extends StatelessWidget {
  const _BadgeTag({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddVehicleCard extends StatelessWidget {
  const _AddVehicleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    return SizedBox(
      width: 80,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: palette.outlineVariant,
            radius: tokens.radiusCard,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surfaceContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(tokens.radiusCard),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: palette.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '添加车辆',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSm.copyWith(
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

class SkeletonVehicleCard extends StatelessWidget {
  const SkeletonVehicleCard({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.palette.surfaceContainer,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
      ),
    );
  }
}

class _WaveLinePainter extends CustomPainter {
  const _WaveLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.charging
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(1, size.height * 0.55)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.05,
        size.width * 0.33,
        size.height * 0.05,
        size.width * 0.5,
        size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height,
        size.width * 0.82,
        size.height,
        size.width - 1,
        size.height * 0.55,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
