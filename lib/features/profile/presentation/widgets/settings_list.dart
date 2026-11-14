import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/domain/app_info.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/profile_models.dart';
import '../../domain/providers.dart';
import 'about_sheet.dart';
import 'privacy_sheet.dart';

class SettingsList extends ConsumerWidget {
  const SettingsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final preferences =
        ref.watch(profilePreferencesProvider).value ??
        const ProfilePreferences();
    final unitLabel = preferences.unitSystem == UnitSystem.metric ? '公制' : '英制';
    final currencyLabel = preferences.currency == CurrencyCode.cny
        ? 'CNY'
        : 'CNY';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: palette.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '系统设置与偏好',
              style: AppTypography.headlineSm.copyWith(
                color: palette.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingRow(
                key: const Key('settings-units'),
                icon: Icons.straighten_rounded,
                title: '单位与货币偏好',
                subtitle: '公制单位（km / kWh / L / ¥）',
                trailing: '$unitLabel · $currencyLabel',
                onTap: () => showAppToast(context, '偏好设置待接入'),
              ),
              _divider(palette),
              _SettingRow(
                key: const Key('settings-privacy'),
                icon: Icons.shield_rounded,
                title: '隐私与数据',
                subtitle: '本地存储、权限与数据使用说明',
                trailing: '查看',
                trailingColor: palette.primaryText,
                onTap: () => _showSheet(context, const PrivacySheet()),
              ),
              _divider(palette),
              _SettingRow(
                key: const Key('settings-notifications'),
                icon: Icons.notifications_active_rounded,
                title: '通知与记账提醒',
                subtitle: '保养到期预警、开销周报',
                trailing: preferences.notificationsEnabled ? '已开启' : '未开启',
                trailingColor: preferences.notificationsEnabled
                    ? palette.primaryText
                    : palette.outline,
                onTap: () => showAppToast(context, '通知设置待接入'),
              ),
              _divider(palette),
              _SettingRow(
                key: const Key('settings-about'),
                icon: Icons.help_center_rounded,
                title: '关于与帮助',
                subtitle: '版本、常见问题与更新日志',
                trailing: 'v${AppInfo.version}',
                onTap: () => _showSheet(context, const AboutSheet()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(AppPalette palette) {
    return Container(height: 1, color: palette.surfaceContainer);
  }

  void _showSheet(BuildContext context, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '$title，$trailing',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: palette.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLg.copyWith(
                          color: palette.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: palette.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  trailing,
                  style: AppTypography.labelMd.copyWith(
                    color: trailingColor ?? palette.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
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
