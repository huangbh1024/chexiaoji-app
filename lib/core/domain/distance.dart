/// 里程来源与聚合口径。
///
/// 账单页、首页、统计页与月度报表共用：优先取里程表读数极差，
/// 读数不足时兜底单笔行驶距离求和。
enum DistanceSource { odometer, records, none }

/// 聚合里程所需的单条采样。
class DistanceSample {
  const DistanceSample({
    required this.vehicleId,
    this.odometerKm,
    this.distanceKm,
  });

  final String vehicleId;

  /// 该笔记录对应的里程表读数（累计里程）。
  final int? odometerKm;

  /// 该笔记录对应的行驶距离（非累计里程）。
  final int? distanceKm;
}

/// 按车聚合里程：每辆车优先用读数极差，否则用单笔距离之和。
({int km, DistanceSource source}) computeDistance(
  Iterable<DistanceSample> samples,
) {
  final readings = <String, List<int>>{};
  final fallback = <String, int>{};

  for (final sample in samples) {
    final odometer = sample.odometerKm;
    if (odometer != null && odometer > 0) {
      readings.putIfAbsent(sample.vehicleId, () => <int>[]).add(odometer);
    }
    final distance = sample.distanceKm;
    if (distance != null && distance > 0) {
      fallback.update(
        sample.vehicleId,
        (value) => value + distance,
        ifAbsent: () => distance,
      );
    }
  }

  final vehicleIds = <String>{...readings.keys, ...fallback.keys};
  var km = 0;
  var usedOdometer = false;
  var usedRecords = false;

  for (final vehicleId in vehicleIds) {
    final values = readings[vehicleId];
    if (values != null && values.length >= 2) {
      values.sort();
      final delta = values.last - values.first;
      if (delta > 0) {
        km += delta;
        usedOdometer = true;
        continue;
      }
    }
    final sum = fallback[vehicleId] ?? 0;
    if (sum > 0) {
      km += sum;
      usedRecords = true;
    }
  }

  final source = usedRecords
      ? DistanceSource.records
      : usedOdometer
      ? DistanceSource.odometer
      : DistanceSource.none;

  return (km: km, source: source);
}
