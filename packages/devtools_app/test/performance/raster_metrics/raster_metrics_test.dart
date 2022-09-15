// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_metrics/raster_metrics.dart';
import 'package:devtools_app/src/screens/performance/panes/raster_metrics/raster_metrics_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../matchers/matchers.dart';
import '../../test_data/performance_raster_metrics.dart';

void main() {
  late TestRasterMetricsController controller;

  group('RasterMetricsController', () {
    setUp(() {
      controller = TestRasterMetricsController();
    });

    test('initDataFromJson', () async {
      await controller.initDataFromJson(renderStats);
      final layerSnapshots = controller.layerSnapshots.value;
      expect(layerSnapshots.length, equals(2));
      expect(controller.originalFrameSize, equals(const Size(100, 200)));
      final first = layerSnapshots[0];
      final second = layerSnapshots[1];
      expect(first.id, equals(12731));
      expect(first.duration.inMicroseconds, equals(389));
      expect(first.totalRenderingDuration!.inMicroseconds, equals(494));
      expect(first.percentRenderingTimeDisplay, equals('78.74%'));
      expect(first.size, equals(const Size(50, 50)));
      expect(first.offset, equals(const Offset(25, 25)));
      expect(second.id, equals(12734));
      expect(second.duration.inMicroseconds, equals(105));
      expect(second.totalRenderingDuration!.inMicroseconds, equals(494));
      expect(second.percentRenderingTimeDisplay, equals('21.26%'));
      expect(second.size, equals(const Size(20, 40)));
      expect(second.offset, equals(const Offset(35, 30)));

      expect(controller.selectedSnapshot.value, equals(first));
    });

    test('clear', () async {
      await controller.initDataFromJson(renderStats);
      expect(controller.layerSnapshots.value.length, equals(2));
      expect(controller.selectedSnapshot.value, isNotNull);
      expect(controller.originalFrameSize, isNotNull);

      controller.clear();

      expect(controller.layerSnapshots.value, isEmpty);
      expect(controller.selectedSnapshot.value, isNull);
      expect(controller.originalFrameSize, isNull);
    });
  });

  group('RenderingLayerVisualizer', () {
    setUp(() async {
      controller = TestRasterMetricsController();
      await controller.initDataFromJson(renderStats);

      setGlobal(IdeTheme, IdeTheme());
    });

    Future<void> pumpRenderingLayerVisualizer(WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          RenderingLayerVisualizer(
            rasterMetricsController: controller,
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
          'Take a snapshot to view raster metrics for the current screen.',
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
        matchesDevToolsGolden('goldens/raster_metrics_with_data.png'),
      );
    });

    testWidgets('can change layer selection', (tester) async {
      await pumpRenderingLayerVisualizer(tester);

      final layers = controller.layerSnapshots.value;
      final firstLayer = layers.first;
      final secondLayer = layers.last;
      expect(firstLayer.displayName, equals('Layer 12731'));
      expect(secondLayer.displayName, equals('Layer 12734'));

      expect(controller.selectedSnapshot.value, equals(firstLayer));

      await tester.tap(find.richText('Layer 12734'));
      await tester.pumpAndSettle();

      expect(controller.selectedSnapshot.value, equals(secondLayer));
      await expectLater(
        find.byType(RenderingLayerVisualizer),
        matchesDevToolsGolden('goldens/raster_metrics_changed_selection.png'),
      );
    });
  });
}

class TestRasterMetricsController extends RasterMetricsController {
  @override
  Future<ui.Image> imageFromBytes(Uint8List bytes) async {
    return MockImage();
  }
}
