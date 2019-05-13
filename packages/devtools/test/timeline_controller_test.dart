// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';

import 'package:devtools/src/timeline/timeline_controller.dart';
import 'package:devtools/src/timeline/timeline_protocol.dart';
import 'package:test/test.dart';

import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';
import 'support/test_utils.dart';

void main() {
  group('TimelineController', () {
    final timelineController = TimelineController();

    final env = FlutterTestEnvironment(
      const FlutterRunConfiguration(withDebugger: true),
    );

    env.afterNewSetup = () async {
      await timelineController.startTimeline();
    };

    // TODO(kenzie): uncomment these methods once we have proper data from the
    //  engine or have a way to handle events from the test device.

//    tearDownAll(() async {
//      await env.tearDownEnvironment(force: true);
//    });
//
//    test('timeline data not empty', () async {
//      await env.setupEnvironment();
//      expect(timelineController.timelineData.frames, isNotEmpty);
//      expect(timelineController.timelineData.frames, isNotEmpty);
//      await env.tearDownEnvironment();
//    });

    // TODO(kenzie): add more tests. We will be able to once we have the proper
    //  data from the engine, allowing us to distinguish cpu events from gpu
    //  events as well as to know accurate frame start times, end times, and
    //  events.
  }, tags: 'useFlutterSdk');

  group('TimelineSnapshot', () {
    test('init from objects', () {
      TimelineSnapshot snapshot = TimelineSnapshot.from(null, null, null);
      expect(snapshot.traceEvents, equals([]));
      expect(snapshot.cpuProfile, equals({}));
      expect(snapshot.selectedEvent, null);
      expect(
        snapshot.encodedJson,
        equals('{"traceEvents":[],"cpuProfile":{},"selectedEvent":{},'
            '"dartDevToolsScreen":"timeline"}'),
      );

      final timelineEvent = testTimelineEvent({
        'name': 'VSYNC',
        'cat': 'Embedder',
        'tid': 1,
        'pid': 94955,
        'ts': 118039650802,
        'ph': 'B',
        'args': {}
      })
        ..time.end = const Duration(microseconds: 118039652422)
        ..type = TimelineEventType.ui;
      snapshot = TimelineSnapshot.from(
        [
          {'name': 'FakeTraceEvent'}
        ],
        {'type': '_CpuProfileTimelineFakeResponse'},
        timelineEvent,
      );
      expect(
        snapshot.traceEvents,
        equals([
          {'name': 'FakeTraceEvent'}
        ]),
      );
      expect(snapshot.cpuProfile,
          equals({'type': '_CpuProfileTimelineFakeResponse'}));
      expect(snapshot.selectedEvent, isA<TimelineEventSnapshot>());
      expect(
        snapshot.selectedEvent.json,
        equals({
          'name': timelineEvent.name,
          'startMicros': timelineEvent.time.start.inMicroseconds,
          'durationMicros': timelineEvent.time.duration.inMicroseconds
        }),
      );
      expect(
        snapshot.encodedJson,
        equals('{"traceEvents":[{"name":"FakeTraceEvent"}],'
            '"cpuProfile":{"type":"_CpuProfileTimelineFakeResponse"},'
            '"selectedEvent":{"name":"VSYNC","startMicros":118039650802,'
            '"durationMicros":1620},"dartDevToolsScreen":"timeline"}'),
      );
    });

    test('parse from json', () {
      TimelineSnapshot snapshot = TimelineSnapshot.parse(jsonDecode(jsonEncode({
        'traceEvents': [],
        'cpuProfile': {},
        'selectedEvent': {},
        'dartDevToolsScreen': 'timeline'
      })));
      expect(snapshot.traceEvents, equals([]));
      expect(snapshot.cpuProfile, equals({}));
      expect(snapshot.selectedEvent, isNull);

      snapshot = TimelineSnapshot.parse(jsonDecode(jsonEncode({
        'traceEvents': [
          {'name': 'FakeTraceEvent'}
        ],
        'cpuProfile': {'type': '_CpuProfileTimelineFakeResponse'},
        'selectedEvent': {
          'name': 'VSYNC',
          'startMicros': 118039650802,
          'durationMicros': 1620
        },
        'dartDevToolsScreen': 'timeline'
      })));
      expect(
        snapshot.traceEvents,
        equals([
          {'name': 'FakeTraceEvent'}
        ]),
      );
      expect(
        snapshot.cpuProfile,
        equals({'type': '_CpuProfileTimelineFakeResponse'}),
      );
      expect(snapshot.selectedEvent, isA<TimelineEventSnapshot>());
      expect(
        snapshot.selectedEvent.json,
        equals({
          'name': 'VSYNC',
          'startMicros': 118039650802,
          'durationMicros': 1620
        }),
      );
    });

    test('TimelineEventSnapshot', () {
      final eventSnapshot = TimelineEventSnapshot('Fake event', 10, 20);
      expect(
        eventSnapshot.json,
        equals({
          'name': 'Fake event',
          'startMicros': 10,
          'durationMicros': 20,
        }),
      );
    });
  });
}
