import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/blurred_header_delegate.dart';
import '../../../core/widgets/section_error.dart';
import '../domain/providers.dart';
import '../domain/report_models.dart';
import 'widgets/report_bottom_dock.dart';
import 'widgets/report_format_cards.dart';
import 'widgets/report_fullscreen_preview.dart';
import 'widgets/report_header.dart';
import 'widgets/report_option_toggles.dart';
import 'widgets/report_paper_preview.dart';
import 'widgets/report_scope_bar.dart';

/// 月度报表与导出页：范围选择 + A4 预览 + 导出配置 + 底部操作栏。
class MonthlyReportPage extends ConsumerStatefulWidget {
  const MonthlyReportPage({super.key, required this.initialScope});

  final ReportScope initialScope;

  @override
  ConsumerState<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends ConsumerState<MonthlyReportPage> {
  late ReportScope _scope = ReportScope(
    month: DateTime(
      widget.initialScope.month.year,
      widget.initialScope.month.month,
    ),
    vehicleId: widget.initialScope.vehicleId,
  );
  ReportOptions _options = const ReportOptions();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onMonthChanged(DateTime month) {
    setState(() {
      _scope = _scope.copyWith(month: monthStart(month));
    });
    _scrollToTop();
  }

  void _onVehicleChanged(String? vehicleId) {
    setState(() {
      _scope = vehicleId == null
          ? _scope.copyWith(clearVehicle: true)
          : _scope.copyWith(vehicleId: vehicleId);
    });
    _scrollToTop();
  }

  void _onOptionsChanged(ReportOptions options) {
    setState(() => _options = options);
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _openFullscreen(MonthlyReport report) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ReportFullscreenPreview(report: report, options: _options),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reportAsync = ref.watch(monthlyReportProvider(_scope));
    final report = reportAsync.value;
    final canExport = report != null && !report.isEmpty;
    final disabledReason = report == null
        ? reportAsync.hasError
              ? '报表加载失败，暂不可导出'
              : null
        : report.isEmpty
        ? '本月暂无可导出的记录'
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: BlurredHeaderDelegate(
                        height: tokens.headerHeight,
                        child: ReportHeader(
                          onBack: () => Navigator.of(context).pop(),
                          onPrint: () => _toast('打印功能将在导出阶段接入'),
                          onShare: () => _toast('分享功能将在导出阶段接入'),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        tokens.contentBottomPadding + 16 + bottomInset,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          ReportScopeBar(
                            scope: _scope,
                            onMonthChanged: _onMonthChanged,
                            onVehicleChanged: _onVehicleChanged,
                          ),
                          const SizedBox(height: 18),
                          const _PreviewHeader(),
                          const SizedBox(height: 8),
                          _buildPreview(reportAsync),
                          const SizedBox(height: 24),
                          ReportFormatCards(
                            value: _options.format,
                            onChanged: (format) => _onOptionsChanged(
                              _options.copyWith(format: format),
                            ),
                            onUnavailable: () => _toast('长图海报即将支持'),
                          ),
                          const SizedBox(height: 12),
                          ReportOptionToggles(
                            options: _options,
                            onChanged: _onOptionsChanged,
                            onUnavailable: () => _toast('发票附件即将支持'),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ReportBottomDock(
                    format: _options.format,
                    enabled: canExport,
                    disabledReason: disabledReason,
                    onFullscreen: () {
                      if (report == null) {
                        _toast('报表加载中');
                        return;
                      }
                      _openFullscreen(report);
                    },
                    onExport: () {
                      if (report == null || report.isEmpty) {
                        _toast('本月暂无可导出的记录');
                        return;
                      }
                      _toast('导出功能将在下一阶段接入');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(AsyncValue<MonthlyReport> reportAsync) {
    return reportAsync.when(
      loading: () => const ReportPaperSkeleton(),
      error: (error, stack) => SectionError(
        message: '报表加载失败',
        onRetry: () => ref.invalidate(monthlyReportProvider(_scope)),
      ),
      data: (report) => ReportPaperPreview(report: report, options: _options),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(Icons.visibility_rounded, size: 18, color: palette.primary),
        const SizedBox(width: 6),
        Text(
          '报表实时预览 (A4标准)',
          style: AppTypography.headlineSm.copyWith(
            color: palette.onSurface,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: palette.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '双指捏合缩放',
            style: AppTypography.labelSm.copyWith(
              color: palette.outline,
              fontSize: 8.5,
            ),
          ),
        ),
      ],
    );
  }
}
