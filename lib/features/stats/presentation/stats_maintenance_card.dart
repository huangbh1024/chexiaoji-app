import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../domain/providers.dart';
import '../domain/stats_models.dart';
import '../domain/stats_presenter.dart';

class StatsMaintenanceCard extends ConsumerWidget {
  const StatsMaintenanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statsFilterProvider);
    final scope = filter.toScope();
    final overview = ref.watch(statsOverviewProvider(scope));

    return overview.when(
      loading: () => const _MaintenanceSkeleton(),
      error: (error, stack) => SectionError(
        onRetry: () => ref.invalidate(statsOverviewProvider(scope)),
        message: '保养数据加载失败',
      ),
      data: (data) => _MaintenanceContent(
        maintenance: data.maintenance,
        showVehicleName: filter.vehicleId == null,
      ),
    );
  }
}

class _MaintenanceContent extends StatelessWidget {
  const _MaintenanceContent({
    required this.maintenance,
    required this.showVehicleName,
  });

  final StatsMaintenance? maintenance;
  final bool showVehicleName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final item = maintenance;

    if (item == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderIcon(color: palette.secondary),
            const SizedBox(height: 12),
            Text(
              '下次建议保养',
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 4),
            Text(
              '暂无保养计划',
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    final warning = item.isWarning || item.isOverdue;
    final accent = warning ? palette.error : palette.secondary;
    final semantic = !item.enabled
        ? '下次建议保养，未设置保养计划'
        : item.isOverdue
        ? '下次建议保养，${item.tag}，已超期 ${maintenanceValue(item)} 公里'
        : '下次建议保养，${item.tag}，还有 ${maintenanceValue(item)} 公里，'
              '${maintenanceDescription(item)}';
    final chipBackground = warning
        ? palette.errorSoft
        : palette.secondary.withValues(alpha: 0.14);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semantic,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HeaderIcon(color: accent),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipBackground,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                  ),
                  child: Text(
                    item.tag,
                    maxLines: 1,
                    style: AppTypography.labelSm.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '下次建议保养',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
            if (showVehicleName && item.enabled) ...[
              const SizedBox(height: 1),
              Text(
                '${item.vehicleName} · 最紧迫',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 2),
            if (!item.enabled)
              TextButton.icon(
                onPressed: () => _toast(context, '保养提醒设置待接入'),
                icon: Icon(
                  Icons.add_alert_rounded,
                  size: 16,
                  color: palette.primaryText,
                ),
                label: Text(
                  '设置保养计划',
                  style: AppTypography.labelMd.copyWith(
                    color: palette.primaryText,
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      maintenanceValue(item),
                      maxLines: 1,
                      style: AppTypography.headlineLg.copyWith(
                        color: palette.onSurface,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isOverdue ? 'km' : 'km 后',
                    style: AppTypography.labelSm.copyWith(
                      color: palette.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            const Spacer(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.enabled ? maintenanceDescription(item) : '添加保养周期后自动提醒',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMd.copyWith(
                      color: warning ? palette.error : palette.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (item.enabled)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (item.progressPercent / 100).clamp(0, 1),
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return ProgressRing(
                        size: 32,
                        progress: value,
                        color: accent,
                        trackColor: palette.surfaceContainer,
                        child: Text(
                          '${item.progressPercent}%',
                          style: AppTypography.labelSm.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.build_rounded, size: 18, color: color),
    );
  }
}

class _MaintenanceSkeleton extends StatelessWidget {
  const _MaintenanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 32, height: 32, radius: 16),
          SizedBox(height: 12),
          SkeletonBox(width: 88, height: 10),
          SizedBox(height: 6),
          SkeletonBox(width: 70, height: 24, radius: 8),
          Spacer(),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SkeletonBox(width: 72, height: 10)),
              SkeletonBox(width: 32, height: 32, radius: 16),
            ],
          ),
        ],
      ),
    );
  }
}
