// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/primitives/trace_event.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/performance/performance_model.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_data/cpu_profile.dart';
import '../test_data/performance.dart';
import '../test_utils/test_utils.dart';

void main() {
  group('PerformanceData', () {
    late PerformanceData performanceData;

    setUp(() {
      performanceData = PerformanceData(
        displayRefreshRate: 60.0,
        timelineEvents: [
          goldenAsyncTimelineEvent,
          goldenUiTimelineEvent,
          goldenRasterTimelineEvent,
          unknownEvent,
        ],
      );
    });

    test('init', () async {
      expect(performanceData.traceEvents, isEmpty);
      expect(performanceData.frames, isEmpty);
      expect(performanceData.selectedFrame, isNull);
      expect(performanceData.selectedFrameId, isNull);
      expect(performanceData.selectedEvent, isNull);
      expect(performanceData.displayRefreshRate, 60.0);
      expect(performanceData.cpuProfileData, isNull);
    });

    test('to json', () {
      expect(
        performanceData.json,
        equals({
          PerformanceData.selectedFrameIdKey: null,
          PerformanceData.flutterFramesKey: [],
          PerformanceData.displayRefreshRateKey: 60,
          PerformanceData.traceEventsKey: [],
          PerformanceData.cpuProfileKey: {},
          PerformanceData.selectedEventKey: {},
        }),
      );

      performanceData = PerformanceData(
        traceEvents: [
          {'name': 'FakeTraceEvent'}
        ],
        frames: [testFrame0, testFrame1],
        selectedEvent: vsyncEvent,
        cpuProfileData: CpuProfileData.parse(goldenCpuProfileDataJson),
        displayRefreshRate: 60,
      );
      expect(
        performanceData.json,
        equals({
          PerformanceData.selectedFrameIdKey: null,
          PerformanceData.traceEventsKey: [
            {'name': 'FakeTraceEvent'}
          ],
          PerformanceData.flutterFramesKey: [
            {
              'number': 0,
              'startTime': 10000,
              'elapsed': 20000,
              'build': 10000,
              'raster': 12000,
              'vsyncOverhead': 10
            },
            {
              'number': 1,
              'startTime': 40000,
              'elapsed': 20000,
              'build': 16000,
              'raster': 16000,
              'vsyncOverhead': 1000
            },
          ],
          PerformanceData.cpuProfileKey: goldenCpuProfileDataJson,
          PerformanceData.selectedEventKey: vsyncEvent.json,
          PerformanceData.displayRefreshRateKey: 60,
        }),
      );
    });

    test('clear', () async {
      performanceData = PerformanceData(
        displayRefreshRate: 120,
        timelineEvents: [
          goldenAsyncTimelineEvent,
          goldenUiTimelineEvent,
          goldenRasterTimelineEvent,
          unknownEvent,
        ],
        traceEvents: [
          {'test': 'trace event'},
        ],
        frames: [testFrame0, testFrame1],
        selectedEvent: vsyncEvent,
        selectedFrame: testFrame0,
        cpuProfileData: CpuProfileData.parse(jsonDecode(jsonEncode({}))),
      );
      expect(performanceData.traceEvents, isNotEmpty);
      expect(performanceData.frames, isNotEmpty);
      expect(performanceData.selectedFrame, isNotNull);
      expect(performanceData.selectedFrameId, 0);
      expect(performanceData.selectedEvent, isNotNull);
      expect(performanceData.displayRefreshRate, equals(120));
      expect(performanceData.cpuProfileData, isNotNull);
      expect(performanceData.timelineEvents, isNotEmpty);

      performanceData.clear();
      expect(performanceData.traceEvents, isEmpty);
      expect(performanceData.frames, isEmpty);
      expect(performanceData.selectedFrame, isNull);
      expect(performanceData.selectedFrameId, isNull);
      expect(performanceData.selectedEvent, isNull);
      expect(performanceData.cpuProfileData, isNull);
      expect(performanceData.timelineEvents, isEmpty);
    });

    test('initializeEventGroups', () {
      expect(performanceData.eventGroups, isEmpty);
      performanceData.initializeEventGroups(threadNamesById);
      expect(
        performanceData
            .eventGroups[PerformanceData.uiKey]!.rows[0].events.length,
        equals(1),
      );
      expect(
        performanceData
            .eventGroups[PerformanceData.rasterKey]!.rows[0].events.length,
        equals(1),
      );
      expect(
        performanceData
            .eventGroups[PerformanceData.unknownKey]!.rows[0].events.length,
        equals(1),
      );
      expect(
        performanceData.eventGroups['A']!.rows[0].events.length,
        equals(1),
      );

      performanceData.addTimelineEvent(rasterTimelineEventWithSubtleShaderJank);
      performanceData.initializeEventGroups(threadNamesById, startIndex: 4);
      expect(
        performanceData
            .eventGroups[PerformanceData.uiKey]!.rows[0].events.length,
        equals(1),
      );
      expect(
        performanceData
            .eventGroups[PerformanceData.rasterKey]!.rows[0].events.length,
        equals(1),
      );
      expect(
        performanceData
            .eventGroups[PerformanceData.rasterKey]!.rows[2].events.length,
        equals(1),
      );
      expect(
        performanceData
            .eventGroups[PerformanceData.unknownKey]!.rows[0].events.length,
        equals(1),
      );
      expect(
        performanceData.eventGroups['A']!.rows[0].events.length,
        equals(1),
      );
    });
  });

  group('OfflinePerformanceData', () {
    test('init from parse', () {
      OfflinePerformanceData offlineData = OfflinePerformanceData.parse({});
      expect(offlineData.traceEvents, isEmpty);
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedFrameId, isNull);
      expect(offlineData.selectedEvent, isNull);
      expect(offlineData.displayRefreshRate, equals(60.0));
      expect(offlineData.cpuProfileData, isNull);

      offlineData = OfflinePerformanceData.parse(offlinePerformanceDataJson);
      expect(
        offlineData.traceEvents,
        equals(goldenTraceEventsJson),
      );
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedFrameId, equals(1));
      expect(offlineData.selectedEvent, isA<OfflineTimelineEvent>());

      final expectedFirstTraceJson =
          Map<String, dynamic>.from(vsyncEvent.beginTraceEventJson);
      expectedFirstTraceJson[TraceEvent.argsKey]
          .addAll({TraceEvent.typeKey: TimelineEventType.ui});
      expectedFirstTraceJson.addAll(
        {TraceEvent.durationKey: vsyncEvent.time.duration.inMicroseconds},
      );
      expect(
        offlineData.selectedEvent!.json,
        equals({TimelineEvent.firstTraceKey: expectedFirstTraceJson}),
      );
      expect(offlineData.displayRefreshRate, equals(120));
      expect(
        offlineData.cpuProfileData!.toJson,
        equals(goldenCpuProfileDataJson),
      );
    });

    test('shallowClone', () {
      final offlineData =
          OfflinePerformanceData.parse(offlinePerformanceDataJson);
      final clone = offlineData.shallowClone();
      expect(offlineData.traceEvents, equals(clone.traceEvents));
      expect(offlineData.frames, equals(clone.frames));
      expect(offlineData.selectedFrame, equals(clone.selectedFrame));
      expect(offlineData.selectedFrameId, equals(clone.selectedFrameId));
      expect(offlineData.selectedEvent, equals(clone.selectedEvent));
      expect(offlineData.displayRefreshRate, equals(clone.displayRefreshRate));
      expect(offlineData.cpuProfileData, equals(clone.cpuProfileData));
      expect(identical(offlineData, clone), isFalse);
    });
  });

  group('SyncTimelineEvent', () {
    test('maybeRemoveDuplicate', () {
      final goldenCopy = goldenUiTimelineEvent.deepCopy();

      // Event with no duplicates should be unchanged.
      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenUiString));

      // Add a duplicate event in [goldenCopy]'s event tree.
      final duplicateEvent = goldenCopy.deepCopy();
      duplicateEvent.parent = goldenCopy;
      duplicateEvent.children
        ..clear()
        ..addAll(goldenCopy.children);
      goldenCopy.children
        ..clear()
        ..add(duplicateEvent);
      expect(goldenCopy.toString(), isNot(equals(goldenUiString)));

      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenUiString));
    });

    test('removeChild', () {
      final goldenCopy = goldenUiTimelineEvent.deepCopy();

      // VSYNC
      //  Animator::BeginFrame
      //   Framework Workload
      //    Engine::BeginFrame <-- [goldenEvent], [copyEvent]
      //     Frame <-- event we will remove
      final TimelineEvent engineBeginFrameEvent =
          goldenCopy.children.first.children.first.children.first;
      expect(engineBeginFrameEvent.name, equals('Engine::BeginFrame'));

      // Ensure [engineBeginFrameEvent]'s only child is the Frame event.
      expect(engineBeginFrameEvent.children.length, equals(1));
      final frameEvent = engineBeginFrameEvent.children.first;
      expect(frameEvent.children.length, equals(7));

      // Remove the Frame event from [engineBeginFrameEvent]'s chiengineBeginFrameEventldren.
      engineBeginFrameEvent.removeChild(frameEvent);

      // Now [frameEvent]'s children are [engineBeginFrameEvent]'s children.
      expect(engineBeginFrameEvent.children.length, equals(7));
      expect(
        collectionEquals(engineBeginFrameEvent.children, frameEvent.children),
        isTrue,
      );
    });

    test('addChild', () {
      final TimelineEvent engineBeginFrame =
          testSyncTimelineEvent(engineBeginFrameTrace);
      expect(engineBeginFrame.children.isEmpty, isTrue);

      // Add child [animate] to a leaf [engineBeginFrame].
      final animate = animateEvent.shallowCopy();
      engineBeginFrame.addChild(animate);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(animateEvent.name));

      // Add child [layout] where child is sibling of existing children
      // [animate].
      final layout = layoutEvent.shallowCopy();
      engineBeginFrame.addChild(layout);
      expect(engineBeginFrame.children.length, equals(2));
      expect(engineBeginFrame.children.last.name, equals(layoutEvent.name));

      // Add child [build] where existing child [layout] is parent of child.
      final build = buildEvent.shallowCopy();
      engineBeginFrame.addChild(build);
      expect(engineBeginFrame.children.length, equals(2));
      expect(layout.children.length, equals(1));
      expect(layout.children.first.name, equals(buildEvent.name));

      // Add child [frame] child is parent of existing children [animate] and
      // [layout].
      final frame = frameEvent.shallowCopy();
      engineBeginFrame.addChild(frame);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(frameEvent.name));
      expect(frame.children.length, equals(2));
      expect(frame.children.first.name, equals(animateEvent.name));
      expect(frame.children.last.name, equals(layoutEvent.name));
    });

    test('frameNumberFromArgs', () {
      expect(goldenUiTimelineEvent.flutterFrameNumber, isNull);
      expect(vsyncEvent.flutterFrameNumber, isNull);
      expect(animatorBeginFrameEvent.flutterFrameNumber, equals(1));
      expect(frameworkWorkloadEvent.flutterFrameNumber, isNull);
      expect(gpuRasterizerDrawEvent.flutterFrameNumber, equals(1));
      expect(pipelineConsumeEvent.flutterFrameNumber, isNull);
    });

    test('isUiFrameIdentifier', () {
      expect(goldenUiTimelineEvent.isUiFrameIdentifier, isFalse);
      expect(vsyncEvent.isUiFrameIdentifier, isFalse);
      expect(animatorBeginFrameEvent.isUiFrameIdentifier, isTrue);
      expect(frameworkWorkloadEvent.isUiFrameIdentifier, isFalse);
    });

    test('isRasterFrameIdentifier', () {
      expect(gpuRasterizerDrawEvent.isRasterFrameIdentifier, isTrue);
      expect(rasterizerDoDrawEvent.isRasterFrameIdentifier, isTrue);
      expect(pipelineConsumeEvent.isRasterFrameIdentifier, isFalse);
    });
  });

  group('AsyncTimelineEvent', () {
    test('isWellFormedDeep', () {
      expect(goldenAsyncTimelineEvent.isWellFormedDeep, isTrue);
      final copy = goldenAsyncTimelineEvent.deepCopy();
      copy.children.last.children.last
          .addChild(AsyncTimelineEvent(asyncStartDTrace));
      expect(copy.isWellFormedDeep, isFalse);
    });

    test('maxEndMicros', () {
      expect(goldenAsyncTimelineEvent.maxEndMicros, equals(193938740983));
    });

    test('displayDepth', () {
      expect(goldenAsyncTimelineEvent.displayDepth, equals(6));
      expect(asyncEventB.displayDepth, equals(3));
      expect(asyncEventC.displayDepth, equals(2));
      expect(asyncEventD.displayDepth, equals(1));
      expect(asyncEventWithDeepOverlap.displayDepth, equals(5));
    });

    test('couldBeParentOf', () {
      expect(asyncEventA.couldBeParentOf(asyncEventB1), isFalse);
      expect(asyncEventB.couldBeParentOf(asyncEventB1), isTrue);
      expect(asyncEventB.couldBeParentOf(asyncEventC1), isFalse);
      expect(asyncEventC.couldBeParentOf(asyncEventC1), isTrue);
      expect(asyncParentId1.couldBeParentOf(asyncChildId1), isTrue);
      expect(asyncParentId1.couldBeParentOf(asyncChildId2), isFalse);
    });

    test('addEndEvent', () {
      final event = AsyncTimelineEvent(asyncStartATrace);
      expect(event.endTraceEventJson, isNull);
      expect(event.time.end, isNull);
      event.addEndEvent(asyncEndATrace);
      expect(event.endTraceEventJson, equals(asyncEndATrace.event.json));
      expect(
        event.time.end!.inMicroseconds,
        asyncEndATrace.event.timestampMicros,
      );
    });
  });

  group('FlutterFrame', () {
    test('shaderDuration', () {
      expect(testFrame0.shaderDuration.inMicroseconds, equals(0));
      expect(testFrame1.shaderDuration.inMicroseconds, equals(0));
      expect(jankyFrame.shaderDuration.inMicroseconds, equals(0));
      expect(jankyFrameUiOnly.shaderDuration.inMicroseconds, equals(0));
      expect(jankyFrameRasterOnly.shaderDuration.inMicroseconds, equals(0));
      expect(
        testFrameWithShaderJank.shaderDuration.inMicroseconds,
        equals(50000),
      );
      expect(
        testFrameWithSubtleShaderJank.shaderDuration.inMicroseconds,
        equals(4000),
      );
    });

    test('hasShaderTime', () {
      expect(testFrame0.hasShaderTime, isFalse);
      expect(testFrame1.hasShaderTime, isFalse);
      expect(jankyFrame.hasShaderTime, isFalse);
      expect(jankyFrameUiOnly.hasShaderTime, isFalse);
      expect(jankyFrameRasterOnly.hasShaderTime, isFalse);
      expect(testFrameWithShaderJank.hasShaderTime, isTrue);
      expect(testFrameWithSubtleShaderJank.hasShaderTime, isTrue);
    });

    test('hasShaderJank', () {
      expect(testFrame0.hasShaderJank(defaultRefreshRate), isFalse);
      expect(testFrame1.hasShaderJank(defaultRefreshRate), isFalse);
      expect(jankyFrame.hasShaderJank(defaultRefreshRate), isFalse);
      expect(jankyFrameUiOnly.hasShaderJank(defaultRefreshRate), isFalse);
      expect(jankyFrameRasterOnly.hasShaderJank(defaultRefreshRate), isFalse);
      expect(testFrameWithShaderJank.hasShaderJank(defaultRefreshRate), isTrue);
      expect(
        testFrameWithSubtleShaderJank.hasShaderJank(defaultRefreshRate),
        isFalse,
      );
    });
  });

  group('FrameAnalysis', () {
    late FlutterFrame frame;
    late FrameAnalysis frameAnalysis;

    setUp(() {
      frame = testFrame0.shallowCopy()
        ..setEventFlow(goldenUiTimelineEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
    });

    test('buildPhase', () {
      final buildPhase = frameAnalysis.buildPhase;
      expect(buildPhase.events.length, equals(2));
      expect(buildPhase.duration.inMicroseconds, equals(83));
    });

    test('layoutPhase', () {
      final layoutPhase = frameAnalysis.layoutPhase;
      expect(layoutPhase.events.length, equals(1));
      expect(layoutPhase.duration.inMicroseconds, equals(211));
    });

    test('paintPhase', () {
      final paintPhase = frameAnalysis.paintPhase;
      expect(paintPhase.events.length, equals(1));
      expect(paintPhase.duration.inMicroseconds, equals(74));
    });

    test('rasterPhase', () {
      final rasterPhase = frameAnalysis.rasterPhase;
      expect(rasterPhase.events.length, equals(1));
      expect(rasterPhase.duration.inMicroseconds, equals(28404));
    });

    test('longestFramePhase', () {
      expect(frameAnalysis.longestUiPhase.title, equals('Layout'));
    });

    test('saveLayerCount', () {
      expect(frameAnalysis.saveLayerCount, equals(1));

      frame = testFrame0.shallowCopy()
        ..setEventFlow(vsyncEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.saveLayerCount, equals(0));
    });

    test('intrinsicOperationsCount', () {
      expect(frameAnalysis.intrinsicOperationsCount, equals(2));

      frame = testFrame0.shallowCopy()
        ..setEventFlow(vsyncEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.intrinsicOperationsCount, equals(0));
    });

    test('hasExpensiveOperations', () {
      expect(frameAnalysis.hasExpensiveOperations, isTrue);

      frame = testFrame0.shallowCopy()
        ..setEventFlow(vsyncEvent)
        ..setEventFlow(goldenRasterTimelineEvent);
      frameAnalysis = FrameAnalysis(frame);
      expect(frameAnalysis.hasExpensiveOperations, isFalse);
    });
  });
}
