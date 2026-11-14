import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/domain/app_info.dart';
import '../../../../core/presentation/toast.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../home/domain/providers.dart';
import '../../domain/providers.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(profileOverviewProvider);
    final nickname = overview.value?.user.nickname;
    final initial = nickname == null || nickname.trim().isEmpty
        ? (overview.hasError ? '?' : '车')
        : String.fromCharCodes(nickname.trim().runes.take(1));

    return AppTabHeader(
      title: AppInfo.name,
      showGreeting: false,
      avatarInitial: initial,
      trailing: const _NotificationButton(),
    );
  }
}

class _NotificationButton extends ConsumerWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final unread = ref.watch(unreadCountProvider);

    return Semantics(
      button: true,
      label: unread > 0 ? '消息，$unread 条未读' : '消息',
      child: Tooltip(
        message: '消息',
        child: Material(
          color: palette.surface.withValues(alpha: 0.95),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => showAppToast(context, '消息中心待接入'),
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                    color: palette.outline,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
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
