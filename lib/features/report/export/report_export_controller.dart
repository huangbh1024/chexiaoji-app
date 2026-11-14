import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/report_models.dart';
import '../domain/report_presenter.dart';
import 'report_exporter.dart';

/// 导出阶段。
enum ReportExportPhase { idle, preparing, generating, sharing, done, failed }

/// 导出状态。由 [ReportExportController] 驱动，页面监听后刷新 UI。
@immutable
class ReportExportState {
  const ReportExportState({
    this.phase = ReportExportPhase.idle,
    this.format = ReportFormat.pdf,
    this.message,
    this.error,
  });

  final ReportExportPhase phase;
  final ReportFormat format;

  /// 阶段文案，如「正在生成 PDF…」。
  final String? message;
  final Object? error;

  bool get isBusy =>
      phase == ReportExportPhase.preparing ||
      phase == ReportExportPhase.generating ||
      phase == ReportExportPhase.sharing;

  ReportExportState copyWith({
    ReportExportPhase? phase,
    ReportFormat? format,
    String? message,
    Object? error,
    bool clearError = false,
  }) {
    return ReportExportState(
      phase: phase ?? this.phase,
      format: format ?? this.format,
      message: message ?? this.message,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 导出状态机：串行执行，防止并发导出；可取消。
class ReportExportController extends ChangeNotifier {
  ReportExportController({required this.exporter, this.onShareDone});

  final ReportExporter exporter;
  final VoidCallback? onShareDone;

  ReportExportState _state = const ReportExportState();
  ReportExportState get state => _state;

  bool _cancelled = false;

  Future<void> export({
    required MonthlyReport report,
    required ReportOptions options,
    required ReportExportAction action,
  }) async {
    if (_state.isBusy) {
      return;
    }
    _cancelled = false;
    _set(
      ReportExportState(
        phase: ReportExportPhase.preparing,
        format: options.format,
      ),
    );

    try {
      final File file = switch (options.format) {
        ReportFormat.pdf => await exporter.buildPdf(report, options),
        ReportFormat.csv => await exporter.buildCsv(report, options),
        ReportFormat.poster => throw const ReportExportException('长图海报即将支持'),
      };
      if (_cancelled) {
        await _deleteQuietly(file);
        return;
      }

      _set(_state.copyWith(phase: ReportExportPhase.sharing));
      final subject = _shareSubject(report);
      switch (action) {
        case ReportExportAction.export || ReportExportAction.share:
          await exporter.share(file, subject: subject);
        case ReportExportAction.print:
          await exporter.print(file, name: _printName(report));
      }

      _set(_state.copyWith(phase: ReportExportPhase.done, message: '报表已生成'));
      onShareDone?.call();
    } catch (error) {
      if (_cancelled) {
        return;
      }
      _set(_state.copyWith(phase: ReportExportPhase.failed, error: error));
    }
  }

  /// 页面销毁时调用：标记取消，生成完成后清理临时文件。
  void cancel() {
    _cancelled = true;
  }

  /// 分享 / 打印完成或失败后回到空闲。
  void reset() {
    _set(const ReportExportState());
  }

  void _set(ReportExportState state) {
    _state = state;
    notifyListeners();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 忽略清理失败。
    }
  }

  String _shareSubject(MonthlyReport report) => '车小记 ${report.monthTitle}';

  String _printName(MonthlyReport report) =>
      '车小记_月度报表_${report.scope.monthKey}';
}
