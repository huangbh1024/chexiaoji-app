import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../report/domain/report_models.dart';
import '../../../report/presentation/report_routes.dart';
import '../../domain/profile_models.dart';
import '../../domain/providers.dart';
import '../profile_style.dart';

class OwnerToolbox extends ConsumerWidget {
  const OwnerToolbox({super.key});

  static const _fallbackServices = ProfileServices(
    report: ProfileServiceStatus(available: true),
    voucher: ProfileServiceStatus(available: false),
    sync: ProfileServiceStatus(available: false, state: SyncState.local),
    offline: ProfileServiceStatus(available: false),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final servicesAsync = ref.watch(profileServicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: palette.tertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '车主核心工具箱',
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '常用高频服务',
              style: AppTypography.labelSm.copyWith(color: palette.outline),
            ),
          ],
        ),
        const SizedBox(height: ProfileStyle.cardGap),
        if (servicesAsync.isLoading &&
            !servicesAsync.hasValue &&
            !servicesAsync.hasError)
          const _ToolboxSkeleton()
        else
          _ToolGrid(services: servicesAsync.value ?? _fallbackServices),
      ],
    );
  }
}

class _ToolGrid extends ConsumerWidget {
  const _ToolGrid({required this.services});

  final ProfileServices services;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = profileTools;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTool(context, ref, tools[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildTool(context, ref, tools[1])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTool(context, ref, tools[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildTool(context, ref, tools[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTool(BuildContext context, WidgetRef ref, ProfileToolSpec spec) {
    final status = _statusFor(spec.kind, services);
    final available = status.available;
    return _ToolCard(
      key: Key(spec.key),
      spec: spec,
      available: available,
      footer: _footerText(spec.kind, available),
      footerColor: spec.kind == ProfileToolKind.report && available
          ? context.palette.primaryText
          : context.palette.outline,
      trailing: _trailing(context, spec.kind, available),
      onTap: () => _onTap(context, ref, spec.kind, available),
    );
  }

  ProfileServiceStatus _statusFor(
    ProfileToolKind kind,
    ProfileServices services,
  ) {
    return switch (kind) {
      ProfileToolKind.report => services.report,
      ProfileToolKind.voucher => services.voucher,
      ProfileToolKind.sync => services.sync,
      ProfileToolKind.offline => services.offline,
    };
  }

  String _footerText(ProfileToolKind kind, bool available) {
    if (kind == ProfileToolKind.report) {
      return '月度对账';
    }
    if (kind == ProfileToolKind.sync) {
      return '本地数据';
    }
    return available ? '可用' : '即将上线';
  }

  Widget? _trailing(
    BuildContext context,
    ProfileToolKind kind,
    bool available,
  ) {
    if (kind == ProfileToolKind.report && available) {
      return const Icon(Icons.arrow_forward_rounded, size: 16);
    }
    if (kind == ProfileToolKind.sync) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: context.palette.outline,
          shape: BoxShape.circle,
        ),
      );
    }
    return const Icon(Icons.schedule_rounded, size: 14);
  }

  void _onTap(
    BuildContext context,
    WidgetRef ref,
    ProfileToolKind kind,
    bool available,
  ) {
    switch (kind) {
      case ProfileToolKind.report:
        final now = DateTime.now();
        openMonthlyReport(
          context,
          ReportScope(
            month: DateTime(now.year, now.month),
            vehicleId: ref.read(profileGarageVehicleIdProvider),
          ),
        );
        return;
      case ProfileToolKind.voucher:
        showAppToast(context, '票夹功能即将上线');
        return;
      case ProfileToolKind.sync:
        showAppToast(context, '当前数据保存在本机，云端同步将在登录功能上线后提供');
        return;
      case ProfileToolKind.offline:
        showAppToast(context, '离线记账功能即将上线');
        return;
    }
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    super.key,
    required this.spec,
    required this.available,
    required this.footer,
    required this.footerColor,
    required this.onTap,
    this.trailing,
  });

  final ProfileToolSpec spec;
  final bool available;
  final String footer;
  final Color footerColor;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    final content = AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: ProfileStyle.iconBox,
                  height: ProfileStyle.iconBox,
                  decoration: BoxDecoration(
                    color: spec.tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(spec.icon, size: 22, color: spec.tint),
                ),
                const SizedBox(height: 12),
                Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm.copyWith(
                    color: palette.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(color: palette.outline),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: palette.surfaceContainer),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          color: footerColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${spec.title}，${available ? '可用' : '即将上线'}',
      child: available ? content : Opacity(opacity: 0.72, child: content),
    );
  }
}

class _ToolboxSkeleton extends StatelessWidget {
  const _ToolboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: _ToolSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _ToolSkeleton()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: _ToolSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _ToolSkeleton()),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolSkeleton extends StatelessWidget {
  const _ToolSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 40, height: 40, radius: 16),
          SizedBox(height: 14),
          SkeletonBox(width: 110, height: 16),
          SizedBox(height: 8),
          SkeletonBox(width: 90, height: 11),
          SizedBox(height: 16),
          SkeletonBox(height: 10),
        ],
      ),
    );
  }
}
