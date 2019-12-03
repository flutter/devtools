// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/profiler/cpu_profile_transformer.dart';
import 'package:devtools_app/src/profiler/flutter/cpu_profile_flame_chart.dart';
import 'package:devtools_app/src/profiler/flutter/cpu_profiler.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('EventDetails', () {
    CpuProfiler cpuProfiler;
    CpuProfileData cpuProfileData;

    setUp(() {
      final transformer = CpuProfileTransformer();
      cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson);
      transformer.processData(cpuProfileData);
    });

    testWidgets('builds for null cpuProfileData', (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: null,
        selectedStackFrame: null,
        onStackFrameSelected: (_) {},
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CpuProfileFlameChart), findsNothing);
    });

    testWidgets('builds for empty cpuProfileData', (WidgetTester tester) async {
      cpuProfileData = CpuProfileData.parse(emptyCpuProfileDataJson);
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        selectedStackFrame: null,
        onStackFrameSelected: (_) {},
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
        selectedStackFrame: null,
        onStackFrameSelected: (_) {},
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
    });

    testWidgets('switches tabs', (WidgetTester tester) async {
      cpuProfiler = CpuProfiler(
        data: cpuProfileData,
        selectedStackFrame: null,
        onStackFrameSelected: (_) {},
      );
      await tester.pumpWidget(wrap(cpuProfiler));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(CpuProfiler.emptyCpuProfile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CpuProfileFlameChart), findsOneWidget);
      expect(find.text('TODO CPU call tree'), findsNothing);
      expect(find.text('TODO CPU bottom up'), findsNothing);

      await tester.tap(find.text('Call Tree'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.text('TODO CPU call tree'), findsOneWidget);
      expect(find.text('TODO CPU bottom up'), findsNothing);

      await tester.tap(find.text('Bottom Up'));
      await tester.pumpAndSettle();
      expect(find.byType(CpuProfileFlameChart), findsNothing);
      expect(find.text('TODO CPU call tree'), findsNothing);
      expect(find.text('TODO CPU bottom up'), findsOneWidget);
    });
  });
}
