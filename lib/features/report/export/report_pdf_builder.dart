import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import '../domain/report_aggregation.dart';
import '../domain/report_models.dart';
import '../domain/report_presenter.dart';

/// PDF 使用的中英文字体。首次加载后缓存，避免重复解析。
class ReportPdfFonts {
  const ReportPdfFonts({
    required this.regular,
    required this.bold,
    required this.cjk,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font cjk;

  static Future<ReportPdfFonts>? _cached;

  static Future<ReportPdfFonts> load() {
    return _cached ??= _load();
  }

  static Future<ReportPdfFonts> _load() async {
    final jakartaRegular = await rootBundle.load(
      'assets/fonts/PlusJakartaSans-Regular.ttf',
    );
    final jakartaBold = await rootBundle.load(
      'assets/fonts/PlusJakartaSans-Bold.ttf',
    );
    final cjk = await rootBundle.load('assets/fonts/DroidSansFallbackFull.ttf');
    return ReportPdfFonts(
      regular: pw.Font.ttf(jakartaRegular),
      bold: pw.Font.ttf(jakartaBold),
      cjk: pw.Font.ttf(cjk),
    );
  }
}

const PdfColor _ink = PdfColor.fromInt(0xFF0B1C30);
const PdfColor _muted = PdfColor.fromInt(0xFF6C7A72);
const PdfColor _line = PdfColor.fromInt(0xFFE5EEFF);
const PdfColor _softFill = PdfColor.fromInt(0xFFF8F9FF);
const PdfColor _vehicleFill = PdfColor.fromInt(0xFFEFF4FF);
const PdfColor _green = PdfColor.fromInt(0xFF00C48C);
const PdfColor _greenText = PdfColor.fromInt(0xFF006C4B);
const PdfColor _orange = PdfColor.fromInt(0xFFFC9D41);
const PdfColor _violet = PdfColor.fromInt(0xFF8B5CF6);
const PdfColor _pink = PdfColor.fromInt(0xFFEC4899);
const PdfColor _amber = PdfColor.fromInt(0xFFEAB308);
const PdfColor _blue = PdfColor.fromInt(0xFF0EA5E9);

/// 生成 A4 单页报表 PDF。
Future<Uint8List> buildReportPdfBytes({
  required MonthlyReport report,
  required ReportOptions options,
  ReportPdfFonts? fonts,
}) async {
  final resolved = fonts ?? await ReportPdfFonts.load();
  final theme = pw.ThemeData.withFont(
    base: resolved.regular,
    bold: resolved.bold,
    fontFallback: [resolved.cjk],
  );

  final document = pw.Document(
    title: '${report.monthTitle} · ${report.vehicleTitle}',
    author: '车小记',
    subject: '月度用车开销报表',
    creator: '车小记',
    theme: theme,
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 22),
      build: (context) => _ReportDocument(
        report: report,
        options: options,
        fonts: resolved,
      ).build(),
    ),
  );

  return document.save();
}

class _ReportDocument {
  const _ReportDocument({
    required this.report,
    required this.options,
    required this.fonts,
  });

  final MonthlyReport report;
  final ReportOptions options;
  final ReportPdfFonts fonts;

  pw.TextStyle style({
    double size = 9,
    bool bold = false,
    PdfColor color = _ink,
  }) {
    return pw.TextStyle(
      font: bold ? fonts.bold : fonts.regular,
      fontFallback: [fonts.cjk],
      fontSize: size,
      color: color,
      lineSpacing: 2,
    );
  }

  pw.Widget build() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(),
        pw.SizedBox(height: 9),
        _vehicleStrip(),
        pw.SizedBox(height: 9),
        _kpiRow(),
        if (options.includeEnergy) ...[pw.SizedBox(height: 9), _trendCard()],
        pw.SizedBox(height: 9),
        _categorySection(),
        pw.Spacer(),
        _footer(),
      ],
    );
  }

  pw.Widget _header() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 5,
                        height: 5,
                        decoration: const pw.BoxDecoration(
                          color: _green,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text('车小记', style: style(size: 15, bold: true)),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        '· AUTO LEDGER',
                        style: style(size: 7, color: _muted),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '用车开销与能耗综合月度分析报告',
                    style: style(size: 9, color: _muted),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('生成单号', style: style(size: 7, color: _muted)),
                pw.Text(report.reportNo, style: style(size: 9, bold: true)),
                pw.Text(report.dateLine, style: style(size: 7, color: _muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.6, color: _line),
      ],
    );
  }

  pw.Widget _vehicleStrip() {
    final vehicles = report.vehicles;
    final single = vehicles.length == 1 ? vehicles.single : null;
    final plate = single == null
        ? null
        : options.maskPlate
        ? maskPlate(single.plate)
        : single.plate;
    final badge = vehicles.length > 1
        ? 'ALL'
        : vehicles.isEmpty
        ? '—'
        : switch (vehicles.single.powertrain) {
            PowertrainType.ev => 'EV',
            PowertrainType.hev => 'HEV',
            PowertrainType.phev => 'PHEV',
            PowertrainType.ice => 'ICE',
          };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: pw.BoxDecoration(
        color: _vehicleFill,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 30,
            height: 30,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0x2B00C48C),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              badge,
              style: style(size: 8, bold: true, color: _greenText),
            ),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Flexible(
                      child: pw.Text(
                        report.vehicleTitle,
                        style: style(size: 13, bold: true),
                        maxLines: 1,
                      ),
                    ),
                    if (plate != null) ...[
                      pw.SizedBox(width: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFD3E4FE),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          plate,
                          style: style(size: 7, color: _muted),
                        ),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  report.vehicleSubtitle,
                  style: style(size: 8, color: _muted),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('累计总里程', style: style(size: 7, color: _muted)),
              pw.Text(
                vehicles.isEmpty ? '—' : formatKm(report.totalOdometerKm),
                style: style(size: 9, bold: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _kpiRow() {
    final cards = <pw.Widget>[
      _kpiCard(
        label: '本月总开销',
        value: formatYuanCompact(report.totalCents),
        note: report.momPercent == null
            ? '较上月 —'
            : '较上月 ${formatSignedPercent(report.momPercent!)}',
        noteColor: report.momTrend == TrendDirection.up
            ? const PdfColor.fromInt(0xFFBA1A1A)
            : report.momTrend == TrendDirection.down
            ? _greenText
            : _muted,
      ),
      if (options.includeEnergy)
        _kpiCard(
          label: '综合每公里',
          value: report.costPerKmText,
          note: report.energyNote,
          valueColor: _greenText,
        ),
      _kpiCard(
        label: '本月行驶',
        value: report.distanceText,
        note: '公里 · ${report.days}天',
      ),
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: cards[index]),
        ],
      ],
    );
  }

  pw.Widget _kpiCard({
    required String label,
    required String value,
    required String note,
    PdfColor? valueColor,
    PdfColor noteColor = _muted,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _softFill,
        borderRadius: pw.BorderRadius.circular(9),
        border: pw.Border.all(color: _line, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: style(size: 8, color: _muted)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: style(size: 16, bold: true, color: valueColor ?? _ink),
            maxLines: 1,
          ),
          pw.SizedBox(height: 3),
          pw.Text(note, style: style(size: 7.5, color: noteColor), maxLines: 2),
        ],
      ),
    );
  }

  pw.Widget _trendCard() {
    final points = report.daily;
    final hasData = points.any((point) => point.totalCents > 0);
    final peakIndex = _peakIndex(points);
    final tickIndices = <int>{
      0,
      points.length ~/ 4,
      peakIndex,
      points.length * 3 ~/ 4,
      points.length - 1,
    };

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: pw.BoxDecoration(
        color: _softFill,
        borderRadius: pw.BorderRadius.circular(9),
        border: pw.Border.all(color: _line, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Text('每日开销走势', style: style(size: 8.5, bold: true)),
              pw.Spacer(),
              _legendDot('充电动能', _green),
              pw.SizedBox(width: 8),
              _legendDot('其他开销', _orange),
            ],
          ),
          pw.SizedBox(height: 5),
          if (!hasData)
            pw.SizedBox(
              height: 74,
              child: pw.Center(
                child: pw.Text(
                  '本月暂无开支数据',
                  style: style(size: 8, color: _muted),
                ),
              ),
            )
          else
            pw.SizedBox(
              height: 74,
              child: pw.CustomPaint(
                size: PdfPoint(520, 74),
                painter: (canvas, size) => _paintChart(
                  canvas,
                  size,
                  points,
                  maxCents: points.fold(
                    0,
                    (max, point) =>
                        point.totalCents > max ? point.totalCents : max,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < points.length; index++)
                if (tickIndices.contains(index))
                  pw.Text(
                    '${points[index].date.month}/${points[index].date.day}'
                    '${index == peakIndex && points[index].dominantCategory != null ? ' (${points[index].dominantCategory!.label})' : ''}',
                    style: style(
                      size: 6.5,
                      color: index == peakIndex ? _orange : _muted,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _legendDot(String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4.5,
          height: 4.5,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 3),
        pw.Text(label, style: style(size: 7, color: _muted)),
      ],
    );
  }

  void _paintChart(
    PdfGraphics canvas,
    PdfPoint size,
    List<ReportDailyPoint> points, {
    required int maxCents,
  }) {
    final width = size.x;
    final height = size.y;
    final maxY = maxCents <= 0 ? 100.0 : maxCents * 1.2;

    canvas
      ..setStrokeColor(const PdfColor.fromInt(0xFFE5EEFF))
      ..setLineWidth(0.5);
    for (var row = 0; row <= 2; row++) {
      final y = height - (height * row / 2);
      canvas
        ..moveTo(0, y)
        ..lineTo(width, y)
        ..strokePath();
    }

    _drawSeries(
      canvas,
      points,
      width,
      height,
      maxY,
      (point) => point.chargingCents,
      const PdfColor.fromInt(0xFF00C48C),
      fillColor: const PdfColor.fromInt(0x2600C48C),
    );
    _drawSeries(
      canvas,
      points,
      width,
      height,
      maxY,
      (point) => point.otherCents,
      const PdfColor.fromInt(0xFFFC9D41),
      fillColor: const PdfColor.fromInt(0x22FC9D41),
      peakIndex: _peakIndex(points),
    );
  }

  void _drawSeries(
    PdfGraphics canvas,
    List<ReportDailyPoint> points,
    double width,
    double height,
    double maxY,
    int Function(ReportDailyPoint) pick,
    PdfColor stroke, {
    PdfColor? fillColor,
    int? peakIndex,
  }) {
    if (points.isEmpty) {
      return;
    }
    final coords = <PdfPoint>[
      for (var index = 0; index < points.length; index++)
        PdfPoint(
          points.length <= 1 ? 0 : width * index / (points.length - 1),
          height - (pick(points[index]) / maxY).clamp(0, 1) * height,
        ),
    ];

    if (fillColor != null) {
      canvas
        ..setFillColor(fillColor)
        ..moveTo(coords.first.x, height)
        ..lineTo(coords.first.x, coords.first.y);
      _appendCurve(canvas, coords);
      canvas
        ..lineTo(coords.last.x, height)
        ..closePath()
        ..fillPath();
    }

    canvas
      ..setStrokeColor(stroke)
      ..setLineWidth(1.4)
      ..moveTo(coords.first.x, coords.first.y);
    _appendCurve(canvas, coords);
    canvas.strokePath();

    if (peakIndex != null &&
        peakIndex >= 0 &&
        peakIndex < coords.length &&
        pick(points[peakIndex]) > 0) {
      final peak = coords[peakIndex];
      canvas
        ..setFillColor(stroke)
        ..drawEllipse(peak.x, peak.y, 2.4, 2.4)
        ..fillPath();
    }
  }

  void _appendCurve(PdfGraphics canvas, List<PdfPoint> coords) {
    for (var index = 1; index < coords.length; index++) {
      final previous = coords[index - 1];
      final current = coords[index];
      final midX = (previous.x + current.x) / 2;
      canvas.curveTo(midX, previous.y, midX, current.y, current.x, current.y);
    }
  }

  pw.Widget _categorySection() {
    final groups = report.categories
        .where((group) => group.count > 0 || group.amountCents != 0)
        .toList(growable: false);
    final barGroups = groups
        .where((group) => group.amountCents > 0)
        .toList(growable: false);
    final rows = <pw.Widget>[];
    for (var index = 0; index < groups.length; index += 2) {
      rows.add(
        pw.Row(
          children: [
            pw.Expanded(child: _categoryLegend(groups[index])),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: index + 1 < groups.length
                  ? _categoryLegend(groups[index + 1])
                  : pw.SizedBox(),
            ),
          ],
        ),
      );
      if (index + 2 < groups.length) {
        rows.add(pw.SizedBox(height: 5));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Text('分类支出核算明细', style: style(size: 8.5, bold: true)),
            pw.Spacer(),
            pw.Text(
              '共 ${report.recordCount} 笔收支',
              style: style(size: 7.5, color: _muted),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.SizedBox(
            height: 8,
            child: barGroups.isEmpty
                ? pw.Container(color: _line)
                : pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      for (final group in barGroups)
                        pw.Expanded(
                          flex: group.amountCents.clamp(1, 1 << 30).toInt(),
                          child: pw.Container(color: _categoryColor(group.key)),
                        ),
                    ],
                  ),
          ),
        ),
        pw.SizedBox(height: 6),
        if (groups.isEmpty)
          pw.Text('本月暂无可核算支出', style: style(size: 8, color: _muted))
        else
          ...rows,
      ],
    );
  }

  pw.Widget _categoryLegend(ReportCategoryGroup group) {
    final percent = group.percent;
    final amount =
        '${formatYuanCompact(group.amountCents)}'
        '${percent == null ? '' : ' ($percent%)'}';
    return pw.Row(
      children: [
        pw.Container(
          width: 4.5,
          height: 4.5,
          decoration: pw.BoxDecoration(
            color: _categoryColor(group.key),
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(group.label, style: style(size: 7.5), maxLines: 1),
        ),
        pw.SizedBox(width: 4),
        pw.Text(amount, style: style(size: 7.5, color: _muted)),
      ],
    );
  }

  PdfColor _categoryColor(ReportCategoryKey key) => switch (key) {
    ReportCategoryKey.charging => _green,
    ReportCategoryKey.fuel => _orange,
    ReportCategoryKey.maintenance => _amber,
    ReportCategoryKey.parking => _blue,
    ReportCategoryKey.toll => _violet,
    ReportCategoryKey.carWashOther => _pink,
  };

  pw.Widget _footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 0.6, color: _line),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 4,
              decoration: const pw.BoxDecoration(
                color: _green,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Text(
                report.verificationText,
                style: style(size: 7.5, color: _greenText),
                maxLines: 1,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(20),
                border: pw.Border.all(
                  color: const PdfColor.fromInt(0x4D006C4B),
                  width: 0.7,
                ),
              ),
              child: pw.Text(
                '车小记 · 月度报表',
                style: style(size: 7, color: _greenText),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('本报表由车小记生成 · 仅供个人对账使用', style: style(size: 6.5, color: _muted)),
      ],
    );
  }

  int _peakIndex(List<ReportDailyPoint> points) {
    var bestIndex = 0;
    var best = -1;
    for (var index = 0; index < points.length; index++) {
      final total = points[index].totalCents;
      if (total > best) {
        best = total;
        bestIndex = index;
      }
    }
    return bestIndex;
  }
}
