import 'package:material_ui/material_ui.dart';

import '../../../core/domain/enums.dart';
import '../../../core/format/formatters.dart';
import 'report_models.dart';

/// 报表展示文案推导。UI 只读结果，不在 Widget 里拼业务字符串。
extension MonthlyReportPresentation on MonthlyReport {
  String get monthTitle => '${formatMonthLabel(scope.month)}用车开销报表';

  String get statusLabel => status == ReportStatus.recording ? '记录中' : '已出账';

  /// 「2026-10-31 结算」或「数据截至 11-14 18:30」。
  String get dateLine {
    if (status == ReportStatus.issued) {
      final date = settledAt ?? updatedAt;
      return '${_formatDate(date)} 结算';
    }
    return '数据截至 ${_formatMonthDayTime(updatedAt)}';
  }

  /// 车辆信息条主标题。
  String get vehicleTitle {
    if (vehicles.length <= 1) {
      return vehicles.isEmpty ? '全部车辆（0 台）' : vehicles.single.name;
    }
    return '全部车辆（${vehicles.length} 台）';
  }

  /// 车辆信息条副标题。
  String get vehicleSubtitle {
    if (vehicles.length > 1) {
      return '${vehicles.length} 辆车的合并报表';
    }
    if (vehicles.isEmpty) {
      return '暂无车辆';
    }
    final vehicle = vehicles.single;
    return '${vehicle.powertrainLabel} · 综合工况良好';
  }

  /// 车辆信息条右侧累计里程。
  int get totalOdometerKm =>
      vehicles.fold(0, (sum, vehicle) => sum + vehicle.odometerKm);

  /// 「综合每公里」卡片的辅助行。
  String get energyNote {
    final hasKwh = energyKwh > 0;
    final hasFuel = fuelLiters > 0;
    if (!hasKwh && !hasFuel) {
      return '暂无能耗数据';
    }
    if (vehicles.length > 1 || (hasKwh && hasFuel)) {
      return [
        if (hasKwh) '充电 ${formatOneDecimal(energyKwh)} kWh',
        if (hasFuel) '加油 ${formatOneDecimal(fuelLiters)} L',
      ].join(' · ');
    }
    if (hasKwh) {
      final per100 = kwhPer100km;
      return per100 == null
          ? '充电 ${formatOneDecimal(energyKwh)} kWh'
          : '${formatOneDecimal(per100)} kWh/100km';
    }
    final per100 = litersPer100km;
    return per100 == null
        ? '加油 ${formatOneDecimal(fuelLiters)} L'
        : '${formatOneDecimal(per100)} L/100km';
  }

  String get costPerKmText =>
      costPerKmCents == null ? '—' : formatYuanDetail(costPerKmCents!);

  String get distanceText => distanceKm <= 0 ? '—' : formatKmValue(distanceKm);

  String get momentumText =>
      momPercent == null ? '较上月 —' : formatSignedPercent(momPercent!);

  /// 全屏预览标题。
  String get fullscreenTitle {
    if (vehicles.length > 1) {
      return '${formatMonthLabel(scope.month)} · 全部车辆';
    }
    return '${formatMonthLabel(scope.month)} · '
        '${vehicles.isEmpty ? '全部车辆' : vehicles.single.name}';
  }
}

/// 报表内车辆动力图标。
IconData reportPowertrainIcon(PowertrainType powertrain) =>
    switch (powertrain) {
      PowertrainType.ev => Icons.electric_car_rounded,
      PowertrainType.hev => Icons.local_gas_station_rounded,
      PowertrainType.phev => Icons.ev_station_rounded,
      PowertrainType.ice => Icons.directions_car_rounded,
    };

/// 导出 CTA 文案。
String reportCtaLabel(ReportFormat format) => switch (format) {
  ReportFormat.pdf => '立即导出 PDF 报表',
  ReportFormat.csv => '导出 Excel / CSV',
  ReportFormat.poster => '生成长图海报',
};

/// 月份标题：`2026年11月用车开销报表`。
String reportMonthTitle(DateTime month) => '${formatMonthLabel(month)}用车开销报表';

/// 当前自然月为记录中，历史月为已出账。
ReportStatus reportStatusFor(DateTime month, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final recording =
      month.year == reference.year && month.month == reference.month;
  return recording ? ReportStatus.recording : ReportStatus.issued;
}

String _formatDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _formatMonthDayTime(DateTime date) =>
    '${_two(date.month)}-${_two(date.day)} ${_two(date.hour)}:${_two(date.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');
