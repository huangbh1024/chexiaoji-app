import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/section_error.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../home/domain/providers.dart';
import '../../domain/profile_presenter.dart';
import '../../domain/providers.dart';

class ProfileSummaryCard extends ConsumerWidget {
  const ProfileSummaryCard({super.key, required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(profileOverviewProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);

    // Riverpod 失败后会自动重试，此时 isLoading 与 hasError 同时为真；
    // 首次失败优先展示错误态，避免一直停在骨架屏。
    if (overviewAsync.hasError && !overviewAsync.hasValue) {
      return SectionError(
        message: '资料加载失败',
        onRetry: () => ref.invalidate(profileOverviewProvider),
      );
    }

    return overviewAsync.when(
      skipError: true,
      loading: () => const _SummarySkeleton(),
      error: (error, stack) => SectionError(
        message: '资料加载失败',
        onRetry: () => ref.invalidate(profileOverviewProvider),
      ),
      data: (overview) {
        final view = buildProfileSummaryView(
          overview: overview,
          vehicleCount: vehiclesAsync.value?.length,
        );
        return _SummaryCard(view: view, onSettingsTap: onSettingsTap);
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.view, required this.onSettingsTap});

  final ProfileSummaryView view;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return AppCard(
      key: const Key('profile-summary-card'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        child: Stack(
          children: [
            const Positioned(
              right: -54,
              top: -64,
              child: IgnorePointer(child: _Aura()),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProfileAvatar(
                        initial: view.initial,
                        size: 56,
                        ringColor: palette.primary.withValues(alpha: 0.22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          label: view.verifiedOwner
                              ? '${view.nickname}，认证车主'
                              : view.nickname,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      view.nickname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.headlineSm.copyWith(
                                        color: palette.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (view.verifiedOwner) ...[
                                    const SizedBox(width: 6),
                                    const _VerifiedBadge(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                view.tagline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySm.copyWith(
                                  color: palette.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: '设置',
                        child: Tooltip(
                          message: '设置',
                          child: Material(
                            color: palette.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: const Key('profile-settings-button'),
                              onTap: onSettingsTap,
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.settings_rounded,
                                  size: 18,
                                  color: palette.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: palette.surfaceContainer),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: view.accountDaysText,
                          label: '记账天数',
                        ),
                      ),
                      _StatDivider(color: palette.surfaceContainer),
                      Expanded(
                        child: _Stat(
                          value: view.recordCountText,
                          label: '累计记录',
                        ),
                      ),
                      _StatDivider(color: palette.surfaceContainer),
                      Expanded(
                        child: _Stat(
                          value: view.vehicleCountText,
                          label: '关联车辆',
                          highlight:
                              view.vehicleCountText != '— 辆' &&
                              view.vehicleCountText != '0 辆',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.tokens.radiusPill),
      ),
      child: Text(
        '认证车主',
        style: AppTypography.labelSm.copyWith(
          color: palette.primaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final split = _splitValueUnit(value);
    return Semantics(
      label: '$label $value',
      child: ExcludeSemantics(
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: split.value,
                      style: AppTypography.headlineSm.copyWith(
                        color: highlight ? palette.primary : palette.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (split.unit != null)
                      TextSpan(
                        text: ' ${split.unit}',
                        style: AppTypography.labelSm.copyWith(
                          color: palette.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(color: palette.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: color);
  }
}

class _Aura extends StatelessWidget {
  const _Aura();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            palette.primary.withValues(alpha: 0.18),
            palette.tertiary.withValues(alpha: 0.04),
            palette.primary.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              SkeletonBox(width: 56, height: 56, radius: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 92, height: 18),
                    SizedBox(height: 8),
                    SkeletonBox(width: 150, height: 12),
                  ],
                ),
              ),
              SkeletonBox(width: 36, height: 36, radius: 12),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 32, radius: 8)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 32, radius: 8)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 32, radius: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

({String value, String? unit}) _splitValueUnit(String text) {
  final index = text.lastIndexOf(' ');
  if (index <= 0 || index == text.length - 1) {
    return (value: text, unit: null);
  }
  return (value: text.substring(0, index), unit: text.substring(index + 1));
}
