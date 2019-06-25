// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';

import 'package:devtools/src/timeline/cpu_profile_model.dart';
import 'package:devtools/src/timeline/timeline_controller.dart';
import 'package:devtools/src/timeline/timeline_model.dart';
import 'package:devtools/src/utils.dart';
import 'package:test/test.dart';

import 'support/cpu_profile_test_data.dart';
import 'support/test_utils.dart';
import 'support/timeline_test_data.dart';

void main() {
  group('TimelineData', () {
    TimelineData timelineData;

    setUp(() {
      timelineData = TimelineData();
    });

    test('init', () {
      expect(timelineData.traceEvents, isEmpty);
      expect(timelineData.frames, isEmpty);
      expect(timelineData.selectedFrame, isNull);
      expect(timelineData.selectedEvent, isNull);
      expect(timelineData.cpuProfileData, isNull);
    });

    test('to json', () {
      expect(
          timelineData.json,
          equals({
            TimelineData.traceEventsKey: [],
            TimelineData.cpuProfileKey: {},
            TimelineData.selectedEventKey: {},
            TimelineData.devToolsScreenKey: timelineScreenId,
          }));

      timelineData
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
            TimelineData.selectedEventKey: vsyncEvent.json,
            TimelineData.devToolsScreenKey: timelineScreenId,
          }));
    });

    test('clear', () {
      final frame = TimelineFrame('id_0');
      timelineData
        ..traceEvents.add({'test': 'trace event'})
        ..frames.add(frame)
        ..selectedEvent = vsyncEvent
        ..selectedFrame = frame
        ..cpuProfileData = CpuProfileData.parse(jsonDecode(jsonEncode({})));
      expect(timelineData.traceEvents, isNotEmpty);
      expect(timelineData.frames, isNotEmpty);
      expect(timelineData.selectedFrame, isNotNull);
      expect(timelineData.selectedEvent, isNotNull);
      expect(timelineData.cpuProfileData, isNotNull);

      timelineData.clear();
      expect(timelineData.traceEvents, isEmpty);
      expect(timelineData.frames, isEmpty);
      expect(timelineData.selectedFrame, isNull);
      expect(timelineData.selectedEvent, isNull);
      expect(timelineData.cpuProfileData, isNull);
    });
  });

  group('OfflineTimelineData', () {
    test('init from parse', () {
      OfflineTimelineData offlineData = OfflineTimelineData.parse({});
      expect(offlineData.traceEvents, isEmpty);
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedEvent, isNull);
      expect(offlineData.cpuProfileData, isNull);

      offlineData = OfflineTimelineData.parse(offlineTimelineDataJson);
      expect(
        offlineData.traceEvents,
        equals(goldenTraceEventsJson),
      );
      expect(offlineData.frames, isEmpty);
      expect(offlineData.selectedFrame, isNull);
      expect(offlineData.selectedEvent, isA<OfflineTimelineEvent>());
      expect(
        offlineData.selectedEvent.json,
        equals({
          TimelineEvent.eventNameKey: vsyncEvent.name,
          TimelineEvent.eventTypeKey: vsyncEvent.type.toString(),
          TimelineEvent.eventStartTimeKey: vsyncEvent.time.start.inMicroseconds,
          TimelineEvent.eventDurationKey:
              vsyncEvent.time.duration.inMicroseconds,
        }),
      );
      expect(offlineData.cpuProfileData.json, equals(goldenCpuProfileDataJson));
    });

    test('copy', () {
      final offlineData = OfflineTimelineData.parse(offlineTimelineDataJson);
      final copy = offlineData.copy();
      expect(offlineData.traceEvents, equals(copy.traceEvents));
      expect(offlineData.frames, equals(copy.frames));
      expect(offlineData.selectedFrame, equals(copy.selectedFrame));
      expect(offlineData.selectedEvent, equals(copy.selectedEvent));
      expect(offlineData.cpuProfileData, equals(copy.cpuProfileData));
      expect(identical(offlineData, copy), isFalse);
    });
  });

  group('TimelineEvent', () {
    test('maybeRemoveDuplicate', () {
      final goldenCopy = goldenUiTimelineEvent.deepCopy();

      // Event with no duplicates should be unchanged.
      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenUiString()));

      // Add a duplicate event in [goldenCopy]'s event tree.
      final duplicateEvent = goldenCopy.deepCopy();
      duplicateEvent.parent = goldenCopy;
      duplicateEvent.children
        ..clear()
        ..addAll(goldenCopy.children);
      goldenCopy.children
        ..clear()
        ..add(duplicateEvent);
      expect(goldenCopy.toString(), isNot(equals(goldenUiString())));

      goldenCopy.maybeRemoveDuplicate();
      expect(goldenCopy.toString(), equals(goldenUiString()));
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
          testTimelineEvent(engineBeginFrameJson);
      expect(engineBeginFrame.children.isEmpty, isTrue);

      // Add child [animate] to a leaf [engineBeginFrame].
      final TimelineEvent animate = testTimelineEvent(animateJson)
        ..time.end = const Duration(microseconds: 118039650871);
      engineBeginFrame.addChild(animate);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(animateEvent.name));

      // Add child [layout] where child is sibling of existing children
      // [animate].
      final TimelineEvent layout = testTimelineEvent(layoutJson)
        ..time.end = const Duration(microseconds: 118039651087);
      engineBeginFrame.addChild(layout);
      expect(engineBeginFrame.children.length, equals(2));
      expect(engineBeginFrame.children.last.name, equals(layoutEvent.name));

      // Add child [build] where existing child [layout] is parent of child.
      final TimelineEvent build = testTimelineEvent(buildJson)
        ..time.end = const Duration(microseconds: 118039651017);
      engineBeginFrame.addChild(build);
      expect(engineBeginFrame.children.length, equals(2));
      expect(layout.children.length, equals(1));
      expect(layout.children.first.name, equals(buildEvent.name));

      // Add child [frame] child is parent of existing children [animate] and
      // [layout].
      final TimelineEvent frame = testTimelineEvent(frameJson)
        ..time.end = const Duration(microseconds: 118039652334);
      engineBeginFrame.addChild(frame);
      expect(engineBeginFrame.children.length, equals(1));
      expect(engineBeginFrame.children.first.name, equals(frameEvent.name));
      expect(frame.children.length, equals(2));
      expect(frame.children.first.name, equals(animateEvent.name));
      expect(frame.children.last.name, equals(layoutEvent.name));
    });
  });
}
