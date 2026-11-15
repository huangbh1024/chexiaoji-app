import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/vehicle_editor_catalog.dart';
import 'vehicle_sheet_shell.dart';

Future<String?> showProvincePicker(
  BuildContext context, {
  required String selected,
}) {
  return showVehicleSheet<String>(
    context,
    (_) => _ProvincePickerSheet(selected: selected),
    maxHeightFactor: 0.85,
  );
}

class _ProvincePickerSheet extends StatelessWidget {
  const _ProvincePickerSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择所属省份简称',
                    style: AppTypography.headlineSm.copyWith(
                      color: palette.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '用于生成标准车牌代码与归属地匹配',
                    style: AppTypography.bodySm.copyWith(
                      color: palette.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: palette.outline),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(
                  icon: Icons.local_fire_department_rounded,
                  color: palette.primary,
                  title: '常用省份推荐',
                  trailing: '快捷选择',
                ),
                const SizedBox(height: 8),
                _ProvinceGrid(
                  provinces: VehicleEditorCatalog.commonProvinces,
                  selected: selected,
                  columns: 6,
                  height: 40,
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                  icon: Icons.map_rounded,
                  color: palette.tertiary,
                  title: '全国省市全览',
                  trailing: '31 个省市区',
                ),
                const SizedBox(height: 8),
                _ProvinceGrid(
                  provinces: VehicleEditorCatalog.allProvinces,
                  selected: selected,
                  columns: 7,
                  height: 36,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.onSurfaceVariant,
              side: BorderSide(color: palette.outlineVariant),
              shape: const StadiumBorder(),
            ),
            child: const Text('取消'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          title,
          style: AppTypography.labelMd.copyWith(
            color: palette.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: AppTypography.labelSm.copyWith(color: palette.outline),
        ),
      ],
    );
  }
}

class _ProvinceGrid extends StatelessWidget {
  const _ProvinceGrid({
    required this.provinces,
    required this.selected,
    required this.columns,
    required this.height,
  });

  final List<String> provinces;
  final String selected;
  final int columns;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.45,
      children: [
        for (final province in provinces)
          Semantics(
            button: true,
            selected: province == selected,
            label: '省份$province',
            child: Material(
              color: province == selected
                  ? palette.primary
                  : palette.surfaceContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(
                province == selected ? 12 : 10,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(province),
                child: Center(
                  child: Text(
                    province,
                    style: AppTypography.headlineSm.copyWith(
                      fontSize: height > 38 ? 16 : 15,
                      color: province == selected
                          ? Colors.white
                          : palette.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
