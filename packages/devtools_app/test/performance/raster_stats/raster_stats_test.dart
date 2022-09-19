// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_stats/raster_stats.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_stats/raster_stats_controller.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../matchers/matchers.dart';
import '../../test_data/performance_raster_stats.dart';

void main() {
  group('RenderingLayerVisualizer', () {
    late RasterStatsController controller;

    setUp(() async {
      final mockServiceManager = MockServiceConnectionManager();
      when(mockServiceManager.renderFrameWithRasterStats).thenAnswer(
        (_) => Future.value(Response.parse(rasterStatsFromService)),
      );
      setGlobal(ServiceConnectionManager, mockServiceManager);
      setGlobal(IdeTheme, IdeTheme());

      controller = RasterStatsController();
      await controller.collectRasterStats();
    });

    Future<void> pumpRenderingLayerVisualizer(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          RenderingLayerVisualizer(
            rasterStatsController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders in empty state', (WidgetTester tester) async {
      controller.clear();
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
        find.byType(RenderingLayerVisualizer),
        matchesDevToolsGolden('goldens/raster_stats_with_data.png'),
      );
    });

    testWidgets('can change layer selection', (tester) async {
      await pumpRenderingLayerVisualizer(tester);

      final layers = controller.rasterStats.value.layerSnapshots;
      final firstLayer = layers.first;
      final secondLayer = layers.last;
      expect(firstLayer.displayName, equals('Layer 12731'));
      expect(secondLayer.displayName, equals('Layer 12734'));

      expect(
        controller.rasterStats.value.selectedSnapshot,
        equals(firstLayer),
      );

      await tester.tap(find.richText('Layer 12734'));
      await tester.pumpAndSettle();

      expect(controller.selectedSnapshot.value, equals(secondLayer));
      await expectLater(
        find.byType(RenderingLayerVisualizer),
        matchesDevToolsGolden('goldens/raster_stats_changed_selection.png'),
      );
    });
  });
}
