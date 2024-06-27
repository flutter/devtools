// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/framework/offline_data/offline_data.dart';
import 'package:devtools_app/src/screens/memory/framework/offline_data/offline_data.dart'
    as offline_data show Json;
import 'package:devtools_app/src/screens/memory/panes/chart/controller/chart_data.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/data/primitives.dart';
import 'package:devtools_app/src/screens/memory/panes/diff/controller/diff_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/profile_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_pane_controller.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/class_filter.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/memory_timeline.dart';
import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/scenes/memory/offline.dart';

// Set a wide enough screen width that we do not run into overflow.
const windowSize = Size(2225.0, 1000.0);

void main() {
  group('Load', () {
    late MemoryOfflineScene scene;

    setUp(() async {
      scene = MemoryOfflineScene();
      await scene.setUp();
    });

    tearDown(() {
      scene.tearDown();
    });

    testWidgetsWithWindowSize(
      'of saved data is successful',
      windowSize,
      (WidgetTester tester) async {
        await scene.pump(tester);

        await scene.tapAndSettle(tester, find.text('Memory chart'));
        expect(find.text('Legend'), findsOneWidget);

        await scene.tapAndSettle(
          tester,
          find.byKey(MemoryScreenKeys.profileTab),
        );
        expect(find.text('_MyHomePageState'), findsOneWidget);

        await scene.tapAndSettle(
          tester,
          find.byKey(MemoryScreenKeys.diffTab),
          pause: const Duration(seconds: 2),
        );
        expect(find.text('Class type legend:'), findsOneWidget);

        await scene.tapAndSettle(
          tester,
          find.byKey(MemoryScreenKeys.traceTab),
        );
        expect(find.text('_MyClass'), findsOneWidget);
      },
    );
  });

  for (final encode in [true, false]) {
    test(
      '$OfflineMemoryData serializes and deserializes correctly, encode: $encode',
      () {
        final item = OfflineMemoryData(
          DiffPaneController(loader: null, rootPackage: 'root'),
          ProfilePaneController(
            mode: ControllerCreationMode.connected,
            rootPackage: 'root',
          ),
          ChartData(
            mode: ControllerCreationMode.offlineData,
            isDeviceAndroid: true,
            timeline: MemoryTimeline(),
            interval: ChartInterval.theDefault,
            isLegendVisible: true,
          ),
          TracePaneController(
            ControllerCreationMode.offlineData,
            rootPackage: '',
          ),
          ClassFilter.empty(),
          selectedTab: 0,
        );

        var json = item.toJson();

        if (encode) {
          final encoded = jsonEncode(json);
          json = jsonDecode(encoded);
        }

        expect(
          json.keys.toSet(),
          equals(offline_data.Json.values.map((e) => e.name).toSet()),
        );
        final fromJson = OfflineMemoryData.fromJson(json);

        expect(fromJson.selectedTab, item.selectedTab);
        expect(fromJson.filter, item.filter);
        expect(
          fromJson.diff.core.snapshots.value.length,
          item.diff.core.snapshots.value.length,
        );
        expect(fromJson.profile!.rootPackage, item.profile!.rootPackage);
        expect(fromJson.chart!.isDeviceAndroid, item.chart!.isDeviceAndroid);
        expect(
          fromJson.chart!.timeline.data.length,
          item.chart!.timeline.data.length,
        );
        expect(
          fromJson.chart!.displayInterval.name,
          item.chart!.displayInterval.name,
        );
        expect(
          fromJson.chart!.isLegendVisible.value,
          item.chart!.isLegendVisible.value,
        );
        expect(
          fromJson.trace!.selection.value.isolate.id,
          item.trace!.selection.value.isolate.id,
        );
        expect(
          fromJson.trace!.stateForIsolate.keys.toSet(),
          item.trace!.stateForIsolate.keys.toSet(),
        );
      },
    );
  }
}
