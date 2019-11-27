// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';

import 'package:devtools_app/src/profiler/cpu_profile_model.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_testing/support/cpu_profile_test_data.dart';
import 'package:devtools_testing/support/test_utils.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:test/test.dart';

void main() {
  group('FrameBasedTimelineData', () {
    FrameBasedTimelineData timelineData;

    setUp(() {
      timelineData = FrameBasedTimelineData(displayRefreshRate: 60.0);
    });

    test('init', () async {
      expect(timelineData.traceEvents, isEmpty);
      expect(timelineData.frames, isEmpty);
      expect(timelineData.selectedFrame, isNull);
      expect(timelineData.selectedFrameId, isNull);
      expect(timelineData.selectedEvent, isNull);
      expect(timelineData.displayRefreshRate, 60.0);
      expect(timelineData.cpuProfileData, isNull);
      expect(timelineData.timelineMode, equals(TimelineMode.frameBased));
    });

    test('to json', () {
      expect(
          timelineData.json,
          equals({
            TimelineData.traceEventsKey: [],
            TimelineData.cpuProfileKey: {},
            FrameBasedTimelineData.selectedFrameIdKey: null,
            TimelineData.selectedEventKey: {},
            FrameBasedTimelineData.displayRefreshRateKey: 60,
            TimelineData.timelineModeKey: TimelineMode.frameBased.toString(),
            TimelineData.devToolsScreenKey: timelineScreenId,
          }));

      timelineData = FrameBasedTimelineData(displayRefreshRate: 60)
        ..traceEvents.add({'name': 'FakeTraceEvent'})
        ..cpuProfileData = CpuProfileData.parse(goldenCpuProfileDataJson)
        ..selectedEvent = vsyncEvent;
      expect(
        timelineData.json,
        equals({
          TimelineData.traceEventsKey: [
            {'name': 'FakeTraceEvent'}
          ],
          TimelineData.cpuProfileKey: goldenCpuProfileDataJson,
          FrameBasedTimelineData.selectedFrameIdKey: null,
          TimelineData.selectedEventKey: vsyncEvent.json,
          FrameBasedTimelineData.displayRefreshRateKey: 60,
          TimelineData.timelineModeKey: TimelineMode.frameBased.toString(),
          TimelineData.devToolsScreenKey: timelineScreenId,
        }),
      );
    });

    test('displayDepth', () {
      timelineData.selectedFrame = testFrame0;
      expect(timelineData.selectedFrame.uiEventFlow.depth, equals(7));
      expect(timelineData.selectedFrame.gpuEventFlow.depth, equals(2));
      expect(timelineData.displayDepth, equals(9));
    });

    test('clear', () async {
      timelineData = FrameBasedTimelineData(displayRefreshRate: 120)
        ..traceEvents.add({'test': 'trace event'})
        ..frames.add(testFrame0)
        ..selectedEvent = vsyncEvent
        ..selectedFrame = testFrame0
        ..cpuProfileData = CpuProfileData.parse(jsonDecode(jsonEncode({})));
      expect(timelineData.traceEvents, isNotEmpty);
      expect(timelineData.frames, isNotEmpty);
      expect(timelineData.selectedFrame, isNotNull);
      expect(timelineData.selectedFrameId, 'id_0');
      expect(timelineData.selectedEvent, isNotNull);
      expect(timelineData.displayRefreshRate, equals(120));
      expect(timelineData.cpuProfileData, isNotNull);

      timelineData.clear();
      expect(timelineData.traceEvents, isEmpty);
      expect(timelineData.frames, isEmpty);
      expect(timelineData.selectedFrame, isNull);
      expect(timelineData.selectedFrameId, isNull);
      expect(timelineData.selectedEvent, isNull);
      expect(timelineData.cpuProfileData, isNull);
    });
  });

  group('FullTimelineData', () {
    FullTimelineData timelineData;
    setUp(() {
      timelineData = FullTimelineData(timelineEvents: [
        goldenAsyncTimelineEvent,
        goldenUiTimelineEvent,
        goldenGpuTimelineEvent,
        unknownEvent,
      ]);
    });

    test('displayDepth', () {
      expect(goldenAsyncTimelineEvent.displayDepth, equals(6));
      expect(goldenUiTimelineEvent.displayDepth, equals(7));
      expect(goldenGpuTimelineEvent.displayDepth, equals(2));
      expect(unknownEvent.displayDepth, equals(1));
      expect(timelineData.displayDepth, equals(16));
    });

    test('initializeEventBuckets', () {
      expect(timelineData.eventGroups, isEmpty);
      timelineData.initializeEventGroups();
      expect(
        timelineData.eventGroups[FullTimelineData.uiKey].eventsByRow[0].length,
        equals(1),
      );
      expect(
        timelineData.eventGroups[FullTimelineData.gpuKey].eventsByRow[0].length,
        equals(1),
      );
      expect(
        timelineData
            .eventGroups[FullTimelineData.unknownKey].eventsByRow[0].length,
        equals(1),
      );
      expect(timelineData.eventGroups['A'].eventsByRow[0].length, equals(1));
    });

    test('event bucket compare', () {
      expect(FullTimelineData.eventGroupComparator('UI', 'GPU'), equals(-1));
      expect(FullTimelineData.eventGroupComparator('GPU', 'UI'), equals(1));
      expect(FullTimelineData.eventGroupComparator('UI', 'UI'), equals(0));
      expect(FullTimelineData.eventGroupComparator('UI', 'Async'), equals(1));
      expect(FullTimelineData.eventGroupComparator('A', 'B'), equals(-1));
      expect(
        FullTimelineData.eventGroupComparator('Z', 'Unknown'),
        equals(-1),
      );
    });
  });

  group('OfflineFrameBasedTimelineData', () {
    test('init from parse', () {
      OfflineFrameBasedTimelineData offlineData =
          OfflineFrameBasedTimelineData.parse({});
      expect(offlineData.traceEvents, isEmpty);
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedFrameId, isNull);
      expect(offlineData.selectedEvent, isNull);
      expect(offlineData.displayRefreshRate, equals(60.0));
      expect(offlineData.cpuProfileData, isNull);
      expect(offlineData.timelineMode, equals(TimelineMode.frameBased));

      offlineData = OfflineFrameBasedTimelineData.parse(
          offlineFrameBasedTimelineDataJson);
      expect(
        offlineData.traceEvents,
        equals(goldenTraceEventsJson),
      );
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedFrameId, equals('PipelineItem-1'));
      expect(offlineData.selectedEvent, isA<OfflineTimelineEvent>());

      final expectedFirstTraceJson =
          Map<String, dynamic>.from(vsyncEvent.beginTraceEventJson);
      expectedFirstTraceJson[TraceEvent.argsKey]
          .addAll({TraceEvent.typeKey: TimelineEventType.ui});
      expectedFirstTraceJson.addAll(
          {TraceEvent.durationKey: vsyncEvent.time.duration.inMicroseconds});
      expect(
        offlineData.selectedEvent.json,
        equals({TimelineEvent.firstTraceKey: expectedFirstTraceJson}),
      );
      expect(offlineData.displayRefreshRate, equals(120));
      expect(offlineData.cpuProfileData.json, equals(goldenCpuProfileDataJson));
      expect(offlineData.timelineMode, equals(TimelineMode.frameBased));
    });

    test('shallowClone', () {
      final offlineData = OfflineFrameBasedTimelineData.parse(
          offlineFrameBasedTimelineDataJson);
      final clone = offlineData.shallowClone();
      expect(offlineData.traceEvents, equals(clone.traceEvents));
      expect(offlineData.frames, equals(clone.frames));
      expect(offlineData.selectedFrame, equals(clone.selectedFrame));
      expect(offlineData.selectedFrameId, equals(clone.selectedFrameId));
      expect(offlineData.selectedEvent, equals(clone.selectedEvent));
      expect(offlineData.displayRefreshRate, equals(clone.displayRefreshRate));
      expect(offlineData.cpuProfileData, equals(clone.cpuProfileData));
      expect(offlineData.timelineMode, equals(clone.timelineMode));
      expect(identical(offlineData, clone), isFalse);
    });
  });

  group('OfflineFullTimelineData', () {
    test('init from parse', () {
      OfflineFullTimelineData offlineData = OfflineFullTimelineData.parse({});
      expect(offlineData.traceEvents, isEmpty);
      expect(offlineData.selectedEvent, isNull);
      expect(offlineData.cpuProfileData, isNull);
      expect(offlineData.timelineMode, equals(TimelineMode.full));

      offlineData = OfflineFullTimelineData.parse(offlineFullTimelineDataJson);
      expect(
        offlineData.traceEvents,
        equals(goldenTraceEventsJson),
      );
      expect(offlineData.selectedEvent, isA<OfflineTimelineEvent>());

      final expectedFirstTraceJson =
          Map<String, dynamic>.from(vsyncEvent.beginTraceEventJson);
      expectedFirstTraceJson[TraceEvent.argsKey]
          .addAll({TraceEvent.typeKey: TimelineEventType.ui});
      expectedFirstTraceJson.addAll(
          {TraceEvent.durationKey: vsyncEvent.time.duration.inMicroseconds});
      expect(
        offlineData.selectedEvent.json,
        equals({TimelineEvent.firstTraceKey: expectedFirstTraceJson}),
      );
      expect(offlineData.cpuProfileData.json, equals(goldenCpuProfileDataJson));
      expect(offlineData.timelineMode, equals(TimelineMode.full));
    });

    test('shallowClone', () {
      final offlineData =
          OfflineFullTimelineData.parse(offlineFullTimelineDataJson);
      final clone = offlineData.shallowClone();
      expect(offlineData.traceEvents, equals(clone.traceEvents));
      expect(offlineData.selectedEvent, equals(clone.selectedEvent));
      expect(offlineData.cpuProfileData, equals(clone.cpuProfileData));
      expect(offlineData.timelineMode, equals(clone.timelineMode));
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
      final TimelineEvent animate = testSyncTimelineEvent(animateTrace)
        ..time.end = const Duration(microseconds: 118039650871);
      engineBeginFrame.addChild(animate);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(animateEvent.name));

      // Add child [layout] where child is sibling of existing children
      // [animate].
      final TimelineEvent layout = testSyncTimelineEvent(layoutTrace)
        ..time.end = const Duration(microseconds: 118039651087);
      engineBeginFrame.addChild(layout);
      expect(engineBeginFrame.children.length, equals(2));
      expect(engineBeginFrame.children.last.name, equals(layoutEvent.name));

      // Add child [build] where existing child [layout] is parent of child.
      final TimelineEvent build = testSyncTimelineEvent(buildTrace)
        ..time.end = const Duration(microseconds: 118039651017);
      engineBeginFrame.addChild(build);
      expect(engineBeginFrame.children.length, equals(2));
      expect(layout.children.length, equals(1));
      expect(layout.children.first.name, equals(buildEvent.name));

      // Add child [frame] child is parent of existing children [animate] and
      // [layout].
      final TimelineEvent frame = testSyncTimelineEvent(frameTrace)
        ..time.end = const Duration(microseconds: 118039652334);
      engineBeginFrame.addChild(frame);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(frameEvent.name));
      expect(frame.children.length, equals(2));
      expect(frame.children.first.name, equals(animateEvent.name));
      expect(frame.children.last.name, equals(layoutEvent.name));
    });
  });

  group('AsyncTimelineEvent', () {
    test('isWellFormedDeep', () {
      expect(goldenAsyncTimelineEvent.isWellFormedDeep, isTrue);
    });

    test('displayDepth', () {
      expect(goldenAsyncTimelineEvent.displayDepth, equals(6));
      expect(asyncEventB.displayDepth, equals(3));
      expect(asyncEventC.displayDepth, equals(2));
      expect(asyncEventD.displayDepth, equals(1));
    });

    test('hasOverlappingChildren', () {
      expect(asyncEventA.hasOverlappingChildren, isTrue);
      expect(asyncEventB.hasOverlappingChildren, isTrue);
      expect(asyncEventC.hasOverlappingChildren, isFalse);
      expect(asyncEventD.hasOverlappingChildren, isFalse);
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
        event.time.end.inMicroseconds,
        asyncEndATrace.event.timestampMicros,
      );
    });
  });
}
