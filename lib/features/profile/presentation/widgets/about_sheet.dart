import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/app_info.dart';
import '../../../app_update/domain/providers.dart';
import '../../../app_update/presentation/app_update_sheet.dart';

class AboutSheet extends ConsumerWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final tokens = context.tokens;
    final updateConfigured = ref
        .watch(appUpdateManifestUrlProvider)
        .trim()
        .isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.heroStart, palette.heroEnd],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: tokens.heroShadow,
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppInfo.name,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMd.copyWith(
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'v${AppInfo.version}',
              textAlign: TextAlign.center,
              style: AppTypography.labelMd.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 8),
            Text(
              AppInfo.tagline,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: palette.surfaceContainer),
            if (updateConfigured) ...[
              const _CheckUpdateRow(),
              Container(height: 1, color: palette.surfaceContainer),
            ],
            const _AboutRow(title: '常见问题', trailing: '即将上线'),
            Container(height: 1, color: palette.surfaceContainer),
            const _AboutRow(title: '更新日志', trailing: 'v${AppInfo.version}'),
            Container(height: 1, color: palette.surfaceContainer),
            const _AboutRow(title: '意见反馈', trailing: '即将上线'),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                  ),
                ),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckUpdateRow extends ConsumerWidget {
  const _CheckUpdateRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final palette = context.palette;
    return _AboutRow(
      key: const Key('settings-check-update'),
      title: '检查更新',
      trailing: _trailingFor(state),
      trailingColor: state.phase == AppUpdatePhase.available
          ? palette.primaryText
          : null,
      onTap: state.isBusy ? null : () => _openUpdateSheet(context, ref),
    );
  }

  String _trailingFor(AppUpdateState state) {
    return switch (state.phase) {
      AppUpdatePhase.idle => 'v${AppInfo.version}',
      AppUpdatePhase.checking => '检查中…',
      AppUpdatePhase.upToDate => '已是最新',
      AppUpdatePhase.available => '发现 v${state.manifest?.version ?? ''}',
      AppUpdatePhase.downloading => '下载中…',
      AppUpdatePhase.installing => '安装中…',
      AppUpdatePhase.installStarted => '等待安装',
      AppUpdatePhase.failed => state.needsInstallPermission ? '需授权' : '重试',
    };
  }

  Future<void> _openUpdateSheet(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final currentState = ref.read(appUpdateControllerProvider);
    final waitingForInstall =
        currentState.phase == AppUpdatePhase.failed &&
        currentState.filePath != null;
    if (!currentState.isBusy && !waitingForInstall) {
      unawaited(controller.checkForUpdate());
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AppUpdateSheet(),
    );

    if (!ref.read(appUpdateControllerProvider).isBusy) {
      controller.reset();
    }
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    super.key,
    required this.title,
    required this.trailing,
    this.onTap,
    this.trailingColor,
  });

  final String title;
  final String trailing;
  final VoidCallback? onTap;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyLg.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            trailing,
            style: AppTypography.labelMd.copyWith(
              color: trailingColor ?? palette.outline,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: palette.outline),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Semantics(
      button: true,
      label: '$title，$trailing',
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
