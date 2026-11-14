import 'package:chexiaoji_app/core/domain/enums.dart';
import 'package:chexiaoji_app/core/format/formatters.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_grouping.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_models.dart';
import 'package:chexiaoji_app/features/ledger/domain/ledger_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerRecord _record({
  required String id,
  required ExpenseCategory category,
  required DateTime occurredAt,
  int amountCents = 5110,
  String title = '特来电快充 · 科技园站',
  LedgerMetrics metrics = const LedgerMetrics(),
  String? description,
  String? statusText,
  String? badgeText,
  LedgerBadgeKind badgeKind = LedgerBadgeKind.vehicle,
}) {
  return LedgerRecord(
    id: id,
    vehicleId: 'byd-han-ev',
    vehicleShortName: '汉 EV',
    powertrain: PowertrainType.ev,
    category: category,
    title: title,
    amountCents: amountCents,
    occurredAt: occurredAt,
    badgeText: badgeText,
    badgeKind: badgeKind,
    description: description,
    metrics: metrics,
    statusText: statusText,
  );
}

void main() {
  group('buildLedgerRows', () {
    final now = DateTime(2026, 11, 14, 10);

    test('按天倒序分组，组头统计当日笔数与合计', () {
      final rows = buildLedgerRows(
        [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 14, 8, 42),
            amountCents: 5110,
          ),
          _record(
            id: 'b',
            category: ExpenseCategory.parking,
            occurredAt: DateTime(2026, 11, 14, 16, 45),
            amountCents: 2400,
          ),
          _record(
            id: 'c',
            category: ExpenseCategory.fuel,
            occurredAt: DateTime(2026, 11, 13, 18, 20),
            amountCents: 20000,
          ),
        ],
        now: now,
      );

      expect(rows, hasLength(5));
      final first = rows.first as LedgerDayHeaderRow;
      expect(first.isToday, isTrue);
      expect(first.count, 2);
      expect(first.totalCents, 7510);
      expect(rows[1], isA<LedgerRecordRow>());
      expect((rows[1] as LedgerRecordRow).record.id, 'b');
      final second = rows[3] as LedgerDayHeaderRow;
      expect(second.isToday, isFalse);
      expect(second.count, 1);
    });

    test('分类筛选时首行插入结果提示条', () {
      final rows = buildLedgerRows(
        [
          _record(
            id: 'a',
            category: ExpenseCategory.charging,
            occurredAt: DateTime(2026, 11, 14, 8, 42),
          ),
        ],
        filteredCategory: ExpenseCategory.charging,
        now: now,
      );

      final bar = rows.first as LedgerResultBarRow;
      expect(bar.category, ExpenseCategory.charging);
      expect(bar.count, 1);
      expect(bar.totalCents, 5110);
    });
  });

  group('LedgerRecordPresentation', () {
    test('充电使用 ¥/kWh 单价胶囊与电量 + 里程副标题', () {
      final record = _record(
        id: 'a',
        category: ExpenseCategory.charging,
        occurredAt: DateTime(2026, 11, 14, 8, 42),
        metrics: const LedgerMetrics(kwh: 38.5, odometerKm: 18426),
      );

      expect(record.unitPricePillText, '¥1.33/kWh');
      expect(record.subtitle, '38.5 kWh · 里程 18,426 km');
      expect(record.expenseText, '-¥51.10');
      expect(record.trailingText, isNull);
    });

    test('加油使用 ¥/L 单价胶囊，副标题不再重复单价', () {
      final record = _record(
        id: 'b',
        category: ExpenseCategory.fuel,
        occurredAt: DateTime(2026, 11, 20, 18, 20),
        amountCents: 20000,
        metrics: const LedgerMetrics(liters: 24.51, odometerKm: 46210),
      );

      expect(record.unitPricePillText, '¥8.16/L');
      expect(record.subtitle, '24.51 L · 里程 46,210 km');
    });

    test('停车展示时长与车牌，状态文案显示在右侧', () {
      final record = _record(
        id: 'c',
        category: ExpenseCategory.parking,
        occurredAt: DateTime(2026, 11, 14, 16, 45),
        amountCents: 2400,
        badgeText: 'B2区',
        badgeKind: LedgerBadgeKind.meta,
        metrics: const LedgerMetrics(
          durationMinutes: 210,
          plate: '粤B·D82K6',
        ),
        statusText: '19:45 离场',
      );

      expect(record.unitPricePillText, isNull);
      expect(record.subtitle, '停车时长 3.5 小时 · 粤B·D82K6');
      expect(record.trailingText, '19:45 离场');
    });

    test('保养展示项目描述，退款显示为正数', () {
      final record = _record(
        id: 'd',
        category: ExpenseCategory.maintenance,
        occurredAt: DateTime(2026, 11, 15, 14, 30),
        amountCents: -2000,
        description: '二保小保养 + CN95空调滤芯更换',
        statusText: '工单已归档',
      );

      expect(record.subtitle, '二保小保养 + CN95空调滤芯更换');
      expect(record.expenseText, '+¥20.00');
      expect(record.trailingText, '工单已归档');
    });
  });

  group('formatters', () {
    test('splitYuanParts 拆分整数与小数', () {
      final parts = splitYuanParts(112050);
      expect(parts.integer, '1,120');
      expect(parts.decimal, '.50');
    });

    test('formatDayTitle 覆盖今天 / 昨天 / 前天 / 普通日期 / 跨年', () {
      final now = DateTime(2026, 11, 14, 10);
      expect(formatDayTitle(DateTime(2026, 11, 14), now: now), '今天 · 11月14日');
      expect(formatDayTitle(DateTime(2026, 11, 13), now: now), '昨天 · 11月13日');
      expect(formatDayTitle(DateTime(2026, 11, 12), now: now), '前天 · 11月12日');
      expect(
        formatDayTitle(DateTime(2026, 11, 8), now: now),
        '11月8日 · 周日',
      );
      expect(
        formatDayTitle(DateTime(2025, 12, 31), now: now),
        '2025年12月31日 · 周三',
      );
    });

    test('formatUnitPrice 与 formatDuration', () {
      expect(formatUnitPrice(133, 'kWh'), '¥1.33/kWh');
      expect(formatUnitPrice(816, 'L'), '¥8.16/L');
      expect(formatDuration(45), '45 分钟');
      expect(formatDuration(120), '2 小时');
      expect(formatDuration(210), '3.5 小时');
    });
  });
}
