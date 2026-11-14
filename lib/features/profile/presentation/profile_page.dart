import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../../home/domain/providers.dart';
import '../domain/providers.dart';
import 'profile_style.dart';
import 'widgets/account_footer.dart';
import 'widgets/garage_section.dart';
import 'widgets/owner_toolbox.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_summary_card.dart';
import 'widgets/settings_list.dart';

/// 我的 Tab：资料 + 车库 + 工具箱 + 设置。
///
/// 底部导航与 FAB 由 [AppTabShell] 统一持有。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _settingsKey = GlobalKey();

  Future<void> _refresh() async {
    final vehicleId = ref.read(profileGarageVehicleIdProvider);
    ref.invalidate(profileOverviewProvider);
    ref.invalidate(vehiclesProvider);
    ref.invalidate(profileGarageProvider);
    ref.invalidate(profileServicesProvider);
    try {
      await ref.read(profileGarageProvider(vehicleId).future);
    } catch (_) {
      // 错误态由各模块自行展示。
    }
  }

  void _scrollToSettings() {
    final target = _settingsKey.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: context.palette.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              key: const Key('profile-scroll'),
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BlurredHeaderDelegate(
                    height: tokens.headerHeight,
                    child: const ProfileHeader(),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.pagePadding,
                    4,
                    tokens.pagePadding,
                    tokens.contentBottomPadding + bottomInset,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ProfileSummaryCard(onSettingsTap: _scrollToSettings),
                      const SizedBox(height: ProfileStyle.sectionGap),
                      const GarageSection(),
                      const SizedBox(height: ProfileStyle.sectionGap),
                      const OwnerToolbox(),
                      const SizedBox(height: ProfileStyle.sectionGap),
                      SettingsList(key: _settingsKey),
                      const SizedBox(height: ProfileStyle.sectionGap),
                      const AccountFooter(),
                    ]),
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
