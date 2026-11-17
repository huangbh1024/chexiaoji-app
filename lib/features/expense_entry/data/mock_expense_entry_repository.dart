import '../../../core/domain/enums.dart';
import '../../../core/domain/payments.dart';
import '../../../core/domain/vehicle.dart';
import '../../../core/format/formatters.dart';
import '../../home/data/home_repository.dart';
import '../../ledger/data/mock_ledger_repository.dart';
import '../../ledger/domain/ledger_models.dart';
import '../domain/expense_entry_detail.dart';
import '../domain/expense_entry_models.dart';
import '../domain/expense_entry_presenter.dart';
import 'expense_entry_repository.dart';

/// 本地记账 Mock：写回 [MockLedgerRepository]，账单 / 统计 / 报表读同一份数据。
class MockExpenseEntryRepository implements ExpenseEntryRepository {
  MockExpenseEntryRepository(
    this.ledger,
    this.home, {
    this.delay = const Duration(milliseconds: 120),
  });

  final MockLedgerRepository ledger;
  final HomeRepository home;
  final Duration delay;

  /// 会话内保存凭证，编辑时能读回；接入接口后由服务端返回。
  final Map<String, List<ReceiptAttachment>> _receiptStore = {};

  @override
  Future<ExpenseEntryDefaults> fetchDefaults(String vehicleId) async {
    await Future<void>.delayed(delay);
    final vehicle = await _vehicleById(vehicleId);
    final latest = ledger.latestOdometerRecord(vehicleId);
    return ExpenseEntryDefaults(
      defaultCategory: switch (vehicle.powertrain) {
        PowertrainType.ev || PowertrainType.phev => ExpenseCategory.charging,
        PowertrainType.hev || PowertrainType.ice => ExpenseCategory.fuel,
      },
      paymentChannel: PaymentChannel.wechat,
      paymentLabel: '微信支付',
      lastPlace: latest?.title,
      unitPrices: const EntryUnitPrices(),
      fuelGrade: vehicle.defaultFuelGrade ?? 95,
      batteryCapacityKwh: vehicle.batteryCapacityKwh,
      tankCapacityL: vehicle.tankCapacityL,
      lastSoc: null,
      lastOdometerKm: latest?.metrics.odometerKm,
      lastCategory: latest?.category,
    );
  }

  @override
  Future<OdometerBaseline> fetchOdometerBaseline({
    required String vehicleId,
    required DateTime before,
    String? excludeRecordId,
  }) async {
    await Future<void>.delayed(delay);
    final vehicle = await _vehicleById(vehicleId);
    final previous = ledger.previousOdometerRecord(
      vehicleId: vehicleId,
      before: before,
      excludeRecordId: excludeRecordId,
    );
    return OdometerBaseline(
      lastReadingKm: previous?.metrics.odometerKm,
      recordedAt: previous?.occurredAt,
      recordId: previous?.id,
      currentOdometerKm: vehicle.odometerKm,
    );
  }

  @override
  Future<ExpenseEntryDraft> fetchDraft(String recordId) async {
    await Future<void>.delayed(delay);
    final record = ledger.recordById(recordId);
    if (record == null) {
      throw const ExpenseEntryValidationException('记录不存在或已被删除');
    }
    final detail = _detailFromRecord(record);
    final paymentLabel = _paymentLabelOf(record);
    return ExpenseEntryDraft(
      vehicleId: record.vehicleId,
      category: record.category,
      amountCents: record.amountCents.abs(),
      occurredAt: record.occurredAt,
      paymentChannel: paymentChannelForLabel(paymentLabel),
      paymentLabel: paymentLabel,
      place: _placeFromRecord(record, detail),
      odometerKm: record.metrics.odometerKm,
      note: record.note,
      receipts: _receiptStore[recordId] ?? const <ReceiptAttachment>[],
      detail: detail,
    );
  }

  @override
  Future<LedgerRecord> createExpense(ExpenseEntryDraft draft) async {
    await Future<void>.delayed(delay);
    final id = 'rec_manual_${DateTime.now().microsecondsSinceEpoch}';
    final record = await _buildRecord(draft, id);
    ledger.insertRecord(record);
    _receiptStore[id] = _activeReceipts(draft.receipts);
    return record;
  }

  @override
  Future<LedgerRecord> updateExpense(
    String recordId,
    ExpenseEntryDraft draft,
  ) async {
    await Future<void>.delayed(delay);
    final existing = ledger.recordById(recordId);
    if (existing == null) {
      throw const ExpenseEntryValidationException('记录不存在或已被删除');
    }
    final record = await _buildRecord(draft, recordId);
    ledger.updateRecord(record);
    _receiptStore[recordId] = _activeReceipts(draft.receipts);
    return record;
  }

  @override
  Future<List<ReceiptAttachment>> uploadReceipts(
    List<ReceiptAttachment> receipts, {
    void Function(String localPath, double progress)? onProgress,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final result = <ReceiptAttachment>[];
    for (final receipt in receipts) {
      if (receipt.isDeleted || receipt.remoteId != null) {
        result.add(receipt);
        continue;
      }
      onProgress?.call(receipt.localPath, 1);
      result.add(receipt.copyWith(remoteId: receipt.localPath));
    }
    return result;
  }

  List<ReceiptAttachment> _activeReceipts(List<ReceiptAttachment> receipts) {
    return [
      for (final receipt in receipts)
        if (!receipt.isDeleted && receipt.remoteId != null) receipt,
    ];
  }

  Future<Vehicle> _vehicleById(String vehicleId) async {
    final vehicles = await home.fetchVehicles();
    for (final vehicle in vehicles) {
      if (vehicle.id == vehicleId) {
        return vehicle;
      }
    }
    throw const ExpenseEntryVehicleMissingException();
  }

  Future<LedgerRecord> _buildRecord(ExpenseEntryDraft draft, String id) async {
    final vehicleId = draft.vehicleId;
    if (vehicleId == null) {
      throw const ExpenseEntryVehicleMissingException();
    }
    final vehicle = await _vehicleById(vehicleId);
    final metrics = LedgerMetrics(
      kwh: switch (draft.detail) {
        ChargingDetail d => d.kwh,
        _ => null,
      },
      liters: switch (draft.detail) {
        FuelDetail d => d.liters,
        _ => null,
      },
      odometerKm: draft.odometerKm,
      distanceKm: draft.distanceKm != null && draft.distanceKm! > 0
          ? draft.distanceKm
          : null,
      durationMinutes: switch (draft.detail) {
        ParkingDetail d => d.durationMinutes,
        _ => null,
      },
      plate: vehicle.plate,
      paymentMethod: draft.paymentLabel,
    );
    return LedgerRecord(
      id: id,
      vehicleId: vehicle.id,
      vehicleShortName: _shortName(vehicle.name),
      vehicleName: vehicle.name,
      powertrain: vehicle.powertrain,
      category: draft.category,
      title: _title(draft),
      amountCents: draft.amountCents,
      occurredAt: draft.occurredAt,
      description: _description(draft),
      metrics: metrics,
      statusText: draft.paymentLabel,
      note: draft.note,
    );
  }

  String _shortName(String name) {
    final parts = name.split(' ');
    return parts.length > 1 ? parts.skip(1).join(' ') : name;
  }

  String _title(ExpenseEntryDraft draft) {
    final place = _trim(draft.place);
    return switch (draft.detail) {
      MaintenanceDetail d => _trim(d.item) ?? place ?? '保养维修',
      CarWashDetail d => place ?? d.serviceType,
      InsuranceDetail d => d.coverageType,
      TollDetail d => _trim(d.roadName) ?? _tollTitle(d) ?? '过路费',
      _ => place ?? draft.category.entryCaption,
    };
  }

  String? _tollTitle(TollDetail detail) {
    final entry = _trim(detail.entryStation);
    final exit = _trim(detail.exitStation);
    if (entry != null && exit != null) {
      return '$entry → $exit';
    }
    return entry ?? exit;
  }

  String? _description(ExpenseEntryDraft draft) {
    return switch (draft.detail) {
      ChargingDetail d => d.kwh == null ? '新能源补能' : '充入 ${formatKwh(d.kwh!)}',
      FuelDetail d =>
        d.liters == null
            ? '燃油加注'
            : '${formatLiters(d.liters!)} · ${d.fuelGrade}#',
      ParkingDetail d =>
        d.durationMinutes == null
            ? '停车缴费'
            : '停车 ${formatDuration(d.durationMinutes!)}',
      TollDetail d =>
        d.distanceKm == null ? '高速通行' : '高速通行 · ${formatKm(d.distanceKm!)}',
      MaintenanceDetail d => _trim(d.shopName) ?? '常规保养',
      CarWashDetail d => d.serviceType,
      InsuranceDetail d =>
        d.policyNo == null ? '保险 / 税费' : '保单尾号 ${_tail(d.policyNo!, 6)}',
      EmptyEntryDetail _ => null,
    };
  }

  EntryCategoryDetail _detailFromRecord(LedgerRecord record) {
    final metrics = record.metrics;
    return switch (record.category) {
      ExpenseCategory.charging => ChargingDetail(
        kwh: metrics.kwh,
        unitPriceCentsPerKwh: _derivedUnitPrice(
          record.amountCents,
          metrics.kwh,
          fallback: 120,
        ),
        socStart: 20,
      ),
      ExpenseCategory.fuel => FuelDetail(
        liters: metrics.liters,
        unitPriceCentsPerLiter: _derivedUnitPrice(
          record.amountCents,
          metrics.liters,
          fallback: 785,
        ),
        fuelGrade: _fuelGrade(record),
      ),
      ExpenseCategory.parking => ParkingDetail(
        rateCentsPerHour: _parkingRate(record),
        durationMinutes: metrics.durationMinutes,
        lotName: record.title,
      ),
      ExpenseCategory.toll => TollDetail(roadName: record.title),
      ExpenseCategory.maintenance => MaintenanceDetail(
        item: record.description ?? record.title,
        shopName: record.title,
        odometerKm: metrics.odometerKm,
      ),
      ExpenseCategory.carWash => CarWashDetail(
        serviceType: record.description ?? '标准洗车',
        shopName: record.title,
      ),
      ExpenseCategory.other => InsuranceDetail(
        coverageType: record.title.contains('交强')
            ? '交强险'
            : record.title.contains('税')
            ? '车船税'
            : '商业险',
      ),
    };
  }

  int _derivedUnitPrice(
    int amountCents,
    double? quantity, {
    required int fallback,
  }) {
    if (quantity == null || quantity <= 0) {
      return fallback;
    }
    return (amountCents / quantity).round();
  }

  int _parkingRate(LedgerRecord record) {
    final minutes = record.metrics.durationMinutes;
    if (minutes == null || minutes <= 0) {
      return 800;
    }
    return (record.amountCents / (minutes / 60)).round();
  }

  int _fuelGrade(LedgerRecord record) {
    final text = '${record.title} ${record.description ?? ''}';
    final match = RegExp(r'(92|95|98)#').firstMatch(text);
    return int.tryParse(match?.group(1) ?? '') ?? 95;
  }

  String? _placeFromRecord(LedgerRecord record, EntryCategoryDetail detail) {
    return switch (detail) {
      MaintenanceDetail d => d.shopName,
      CarWashDetail d => d.shopName,
      _ => record.title,
    };
  }

  /// 支付方式优先取记录里的 `paymentMethod`；`statusText` 是右侧辅助文案
  /// （如「19:45 离场」「工单已归档」），不能当作支付方式。
  String _paymentLabelOf(LedgerRecord record) {
    final method = _trim(record.metrics.paymentMethod);
    return method ?? defaultPaymentLabelFor(record.category);
  }

  String? _trim(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _tail(String value, int length) {
    if (value.length <= length) {
      return value;
    }
    return value.substring(value.length - length);
  }
}
