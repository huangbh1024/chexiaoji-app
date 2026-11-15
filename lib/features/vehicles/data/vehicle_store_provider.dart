import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vehicle_seed_data.dart';
import 'vehicle_store.dart';

/// 车库内存状态的唯一实例；首页、本页与各选择器共用。
final vehicleStoreProvider = Provider<VehicleStore>(
  (ref) => seededVehicleStore(),
);
