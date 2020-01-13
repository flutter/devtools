// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/profiler/cpu_profiler_controller.dart';
import 'package:devtools_app/src/profiler/flutter/cpu_profile_call_tree.dart';
import 'package:devtools_app/src/profiler/flutter/cpu_profile_flame_chart.dart';
import 'package:devtools_app/src/profiler/flutter/cpu_profiler.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  CpuProfiler cpuProfiler;
  CpuProfileData cpuProfileData;
  CpuProfilerController controller;

  setUp(() {
    final transformer = CpuProfileTransformer();
    controller = CpuProfilerController();
    cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson);
    transformer.processData(cpuProfileData);
  });

  group('Cpu Profiler', () {
    testWidgets('builds for null cpuProfileData', (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: null,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsNothing);

      // Null data while controller is pulling and processing data.
      controller.processingValueNotifier.value = true;
      await tester.pump();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
    });

    testWidgets('builds for empty cpuProfileData', (WidgetTester tester) async {
      cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
    });

    testWidgets('builds for valid cpuProfileData', (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
    });

    testWidgetsWithWindowSize('switches tabs', const Size(1000, 1000),
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.text('TODO CPU bottom up'), findsNothing);
      expect(find.byKey(CpuProfiler.expandButtonKey), findsNothing);
      expect(find.byKey(CpuProfiler.collapseButtonKey), findsNothing);

      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsOneWidget);
      expect(find.text('TODO CPU bottom up'), findsNothing);
      expect(find.byKey(CpuProfiler.expandButtonKey), findsOneWidget);
      expect(find.byKey(CpuProfiler.collapseButtonKey), findsOneWidget);

      await tester.tap(find.text('Bottom Up'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.byType(CpuCallTreeTable), findsNothing);
      expect(find.text('TODO CPU bottom up'), findsOneWidget);
      expect(find.byKey(CpuProfiler.expandButtonKey), findsOneWidget);
      expect(find.byKey(CpuProfiler.collapseButtonKey), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'can expand and collapse data', const Size(1000, 1000),
        (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        controller: controller,
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();
      expect(cpuProfileData.cpuProfileRoot.isExpanded, false);
      await tester.tap(find.byKey(CpuProfiler.expandButtonKey));
      expect(cpuProfileData.cpuProfileRoot.isExpanded, true);
      await tester.tap(find.byKey(CpuProfiler.collapseButtonKey));
      expect(cpuProfileData.cpuProfileRoot.isExpanded, false);
    });
  });
}
