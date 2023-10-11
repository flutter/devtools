// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_stats/raster_stats.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/matchers/matchers.dart';
import '../../test_infra/test_data/performance_raster_stats.dart';

void main() {
  group('$RasterStatsView', () {
    late RasterStatsController controller;

    setUp(() async {
      final mockServiceConnection = createMockServiceConnectionWithDefaults();
      when(mockServiceConnection.renderFrameWithRasterStats).thenAnswer(
        (_) => Future.value(Response.parse(rasterStatsFromServiceJson)),
      );
      setGlobal(ServiceConnectionManager, mockServiceConnection);
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());

      controller =
          RasterStatsController(createMockPerformanceControllerWithDefaults());
      await controller.collectRasterStats();
    });

    Future<void> pumpRenderingLayerVisualizer(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          RasterStatsView(
            rasterStatsController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders in empty state', (WidgetTester tester) async {
      controller.clearData();
      await pumpRenderingLayerVisualizer(tester);

      expect(find.byType(LayerSnapshotTable), findsNothing);
      expect(find.byType(LayerImage), findsNothing);
      expect(
        find.text(
          'Take a snapshot to view raster stats for the current screen.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders with data', (tester) async {
      await pumpRenderingLayerVisualizer(tester);

      expect(find.byType(LayerSnapshotTable), findsOneWidget);
      expect(find.richText('Layer'), findsOneWidget);
      expect(find.richText('Rendering time'), findsOneWidget);
      expect(find.richText('Percent rendering time'), findsOneWidget);
      expect(find.richText('Layer 12731'), findsOneWidget);
      expect(find.richText('0.4 ms'), findsOneWidget);
      expect(find.richText('78.74%'), findsOneWidget);
      expect(find.richText('Layer 12734'), findsOneWidget);
      expect(find.richText('0.1 ms'), findsOneWidget);
      expect(find.richText('21.26%'), findsOneWidget);

      expect(find.byType(LayerImage), findsOneWidget);

      await expectLater(
        find.byType(RasterStatsView),
        matchesDevToolsGolden('goldens/raster_stats_with_data.png'),
      );
    });

    testWidgets('can change layer selection', (tester) async {
      await pumpRenderingLayerVisualizer(tester);

      final rasterStats = controller.rasterStats.value!;
      final layers = rasterStats.layerSnapshots;
      final firstLayer = layers.first;
      final secondLayer = layers.last;
      expect(firstLayer.displayName, equals('Layer 12731'));
      expect(secondLayer.displayName, equals('Layer 12734'));

      expect(rasterStats.selectedSnapshot, equals(firstLayer));

      await tester.tap(find.richText('Layer 12734'));
      await tester.pumpAndSettle();

      expect(controller.selectedSnapshot.value, equals(secondLayer));
      await expectLater(
        find.byType(RasterStatsView),
        matchesDevToolsGolden('goldens/raster_stats_changed_selection.png'),
      );
    });
  });
}
