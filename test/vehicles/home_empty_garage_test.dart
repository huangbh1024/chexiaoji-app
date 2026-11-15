import 'package:chexiaoji_app/app/app.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_seed_data.dart';
import 'package:chexiaoji_app/features/vehicles/data/vehicle_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('空车库时首页展示空态而不崩溃', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = seededVehicleStore(now: DateTime(2026, 11, 15));
    for (final record in store.active.toList()) {
      store.archive(record.id, at: DateTime(2026, 11, 15));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [vehicleStoreProvider.overrideWithValue(store)],
        child: const CheXiaoJiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加爱车后查看能耗与开销'), findsOneWidget);
    expect(find.text('添加车辆'), findsOneWidget);
    expect(find.text('比亚迪 汉 EV'), findsNothing);
  });
}
