import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';

class ArchivedVehiclesHeader extends StatelessWidget {
  const ArchivedVehiclesHeader({
    super.key,
    required this.count,
    required this.isLoading,
    required this.hasError,
  });

  final int? count;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SizedBox(
        height: tokens.headerHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.pagePadding),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: '返回',
                child: Material(
                  color: palette.surface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: palette.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已归档车辆',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd.copyWith(
                        color: palette.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    _Subtitle(
                      count: count,
                      isLoading: isLoading,
                      hasError: hasError,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.count,
    required this.isLoading,
    required this.hasError,
  });

  final int? count;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = AppTypography.bodySm.copyWith(color: palette.outline);

    if (count == null) {
      final text = hasError
          ? '档案读取失败，请重试'
          : isLoading
          ? '正在读取封存档案…'
          : '暂无封存座驾';
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    if (count == 0) {
      return Text(
        '暂无封存座驾',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '共 '),
          TextSpan(
            text: '$count',
            style: AppTypography.labelMd.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' 辆封存座驾 · 历史流水安全保留'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
