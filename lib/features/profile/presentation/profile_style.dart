import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';

enum ProfileToolKind { report, voucher, sync, offline }

@immutable
class ProfileToolSpec {
  const ProfileToolSpec({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.kind,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final ProfileToolKind kind;
}

const profileTools = <ProfileToolSpec>[
  ProfileToolSpec(
    key: 'tool-report',
    title: '账单导出与报表',
    subtitle: '支持 Excel / PDF 明细',
    icon: Icons.receipt_long_rounded,
    tint: AppColors.charging,
    kind: ProfileToolKind.report,
  ),
  ProfileToolSpec(
    key: 'tool-voucher',
    title: '智能 OCR 票夹',
    subtitle: '加油 / 充电凭证自动识别',
    icon: Icons.document_scanner_rounded,
    tint: AppColors.parking,
    kind: ProfileToolKind.voucher,
  ),
  ProfileToolSpec(
    key: 'tool-sync',
    title: '云端数据同步',
    subtitle: '多端实时备份',
    icon: Icons.cloud_sync_rounded,
    tint: AppColors.fuel,
    kind: ProfileToolKind.sync,
  ),
  ProfileToolSpec(
    key: 'tool-offline',
    title: '离线记账与缓存',
    subtitle: '地库弱网环境可记账',
    icon: Icons.wifi_off_rounded,
    tint: AppColors.other,
    kind: ProfileToolKind.offline,
  ),
];

class ProfileStyle {
  const ProfileStyle._();

  static const sectionGap = 20.0;
  static const cardGap = 12.0;
  static const pillMaxWidth = 168.0;
  static const pillHeight = 34.0;
  static const iconBox = 40.0;
}
