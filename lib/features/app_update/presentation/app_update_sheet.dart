import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/providers.dart';

/// 全量更新浮层：检查、下载、安装与错误重试。
///
/// 不允许点击遮罩或下拉关闭；有更新时通过「稍后」退出，必须更新时只能
/// 安装或按系统返回（强制更新阶段会拦截返回）。
class AppUpdateSheet extends ConsumerWidget {
  const AppUpdateSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final palette = context.palette;
    final manifest = state.manifest;
    final current = state.current;
    final blocking =
        manifest != null && current != null && manifest.isBlocking(current);
    final canPop =
        !(blocking &&
            (state.phase == AppUpdatePhase.available ||
                state.phase == AppUpdatePhase.downloading ||
                state.phase == AppUpdatePhase.installing ||
                state.phase == AppUpdatePhase.installStarted));

    return PopScope(
      canPop: canPop,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: SingleChildScrollView(
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
                Text(
                  _titleFor(state),
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMd.copyWith(
                    color: palette.onSurface,
                  ),
                ),
                if (manifest != null && current != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'v${current.name} → v${manifest.version}',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMd.copyWith(
                      color: palette.outline,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _body(context, controller, state, manifest, blocking),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppUpdateController controller,
    AppUpdateState state,
    AppUpdateManifest? manifest,
    bool blocking,
  ) {
    final palette = context.palette;
    final progress = state.progress;

    switch (state.phase) {
      case AppUpdatePhase.idle:
        return _centered(
          children: [
            Text(
              '准备检查更新…',
              style: AppTypography.bodyMd.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              context,
              '检查更新',
              () => controller.checkForUpdate(),
              key: const Key('update-check'),
            ),
          ],
        );
      case AppUpdatePhase.checking:
        return _centered(
          children: [
            Center(child: CircularProgressIndicator(color: palette.primary)),
            const SizedBox(height: 16),
            Text(
              '正在检查更新…',
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              key: const Key('update-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      case AppUpdatePhase.upToDate:
        return _centered(
          children: [
            Icon(Icons.check_circle_rounded, size: 44, color: palette.primary),
            const SizedBox(height: 12),
            Text(
              '当前已是最新版本',
              style: AppTypography.bodyLg.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              context,
              '知道了',
              () => Navigator.of(context).pop(),
              key: const Key('update-close'),
            ),
          ],
        );
      case AppUpdatePhase.available:
        return _availableBody(context, controller, manifest, blocking);
      case AppUpdatePhase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: palette.surfaceContainer,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              progress == null
                  ? '正在下载安装包…'
                  : '正在下载 ${(progress * 100).floor()}%',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请保持网络连接，下载完成后会自动打开系统安装程序。',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
          ],
        );
      case AppUpdatePhase.installing:
        return _centered(
          children: [
            Center(child: CircularProgressIndicator(color: palette.primary)),
            const SizedBox(height: 14),
            Text(
              '正在校验安装包…',
              style: AppTypography.bodyLg.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '校验通过后会打开系统安装界面。',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
          ],
        );
      case AppUpdatePhase.installStarted:
        return _centered(
          children: [
            Icon(Icons.check_circle_rounded, size: 44, color: palette.primary),
            const SizedBox(height: 12),
            Text(
              '已打开系统安装界面',
              style: AppTypography.bodyLg.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请按系统提示完成安装；安装完成后重新打开车小记即可。',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: palette.outline),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              context,
              '完成',
              () => Navigator.of(context).pop(),
              key: const Key('update-close'),
            ),
          ],
        );
      case AppUpdatePhase.failed:
        return _failedBody(context, controller, state);
    }
  }

  Widget _availableBody(
    BuildContext context,
    AppUpdateController controller,
    AppUpdateManifest? manifest,
    bool blocking,
  ) {
    final palette = context.palette;
    final changelog = manifest?.changelog?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ManifestInfoCard(manifest: manifest!, blocking: blocking),
        if (changelog != null && changelog.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '更新内容',
            style: AppTypography.labelLg.copyWith(
              color: palette.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              changelog,
              style: AppTypography.bodyMd.copyWith(
                color: palette.onSurfaceVariant,
                height: 20 / 13,
              ),
            ),
          ),
        ],
        if (blocking) ...[
          const SizedBox(height: 12),
          Text(
            '该版本为必须更新，完成后才能继续使用。',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: palette.error),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            if (!blocking) ...[
              Expanded(
                child: TextButton(
                  key: const Key('update-later'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '稍后',
                    style: AppTypography.labelLg.copyWith(
                      color: palette.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _primaryButton(
                context,
                '立即更新',
                () => controller.downloadAndInstall(),
                key: const Key('update-install'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _failedBody(
    BuildContext context,
    AppUpdateController controller,
    AppUpdateState state,
  ) {
    final palette = context.palette;
    final VoidCallback retry = state.manifest == null
        ? () => controller.checkForUpdate()
        : () => controller.retryInstall();

    return _centered(
      children: [
        Icon(Icons.error_outline_rounded, size: 44, color: palette.error),
        const SizedBox(height: 12),
        Text(
          state.message ?? '操作失败，请稍后重试',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: palette.onSurfaceVariant,
            height: 20 / 13,
          ),
        ),
        const SizedBox(height: 20),
        if (state.needsInstallPermission) ...[
          _primaryButton(
            context,
            '去设置',
            () => controller.openInstallPermissionSettings(),
            key: const Key('update-settings'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('update-retry'),
            onPressed: () => controller.retryInstall(),
            child: const Text('我已允许，重试安装'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('update-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ] else ...[
          _primaryButton(context, '重试', retry, key: const Key('update-retry')),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('update-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ],
    );
  }

  Widget _centered({required List<Widget> children}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _primaryButton(
    BuildContext context,
    String label,
    VoidCallback? onPressed, {
    Key? key,
  }) {
    final palette = context.palette;
    return SizedBox(
      height: 48,
      child: FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }

  String _titleFor(AppUpdateState state) {
    switch (state.phase) {
      case AppUpdatePhase.idle:
      case AppUpdatePhase.checking:
        return '检查更新';
      case AppUpdatePhase.upToDate:
        return '已是最新版本';
      case AppUpdatePhase.failed:
        return state.manifest == null ? '检查更新' : '发现新版本';
      case AppUpdatePhase.available:
      case AppUpdatePhase.downloading:
      case AppUpdatePhase.installing:
      case AppUpdatePhase.installStarted:
        return '发现新版本';
    }
  }
}

class _ManifestInfoCard extends StatelessWidget {
  const _ManifestInfoCard({required this.manifest, required this.blocking});

  final AppUpdateManifest manifest;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = manifest.sizeBytes;
    final publishedAt = manifest.publishedAt;
    if (size == null && publishedAt == null && !blocking) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (size != null) _InfoRow(label: '安装包大小', value: _formatBytes(size)),
          if (publishedAt != null)
            _InfoRow(label: '发布时间', value: _formatDate(publishedAt)),
          if (blocking)
            _InfoRow(label: '更新要求', value: '必须更新', valueColor: palette.error),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.bodySm.copyWith(color: palette.outline),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              color: valueColor ?? palette.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const megabyte = 1024 * 1024;
  if (bytes >= megabyte) {
    return '${(bytes / megabyte).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
