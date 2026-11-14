import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/providers.dart';

class AccountFooter extends ConsumerWidget {
  const AccountFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final phone = ref.watch(profileOverviewProvider).value?.user.phoneMasked;
    if (phone == null || phone.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: const Key('profile-account-footer'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '当前绑定手机：$phone · 手机号已掩码显示',
        textAlign: TextAlign.center,
        style: AppTypography.labelSm.copyWith(
          color: palette.outline.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
