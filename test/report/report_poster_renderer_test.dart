import 'dart:ui' as ui;

import 'package:chexiaoji_app/features/report/domain/report_aggregation.dart';
import 'package:chexiaoji_app/features/report/domain/report_models.dart';
import 'package:chexiaoji_app/features/report/presentation/report_poster_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('长图离屏渲染输出 PNG', (tester) async {
    late BuildContext appContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            appContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    final report = buildMonthlyReport(
      scope: ReportScope(month: DateTime(2026, 11)),
      records: const [],
      vehicles: const [],
      now: DateTime(2026, 11, 14, 10),
    );

    final future = ReportPosterRenderer.capture(
      appContext,
      report: report,
      options: const ReportOptions(maskPlate: true),
    );
    await tester.pump();

    final bytes = await tester.runAsync(() => future);
    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 8), const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    expect(bytes.length, greaterThan(1000));

    final size = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      return size;
    });
    expect(size!.width, 1080);
    expect(size.height, greaterThan(size.width));
  });
}
