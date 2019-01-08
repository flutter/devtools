// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools/timeline/timeline_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('TimelineData', () {
    test('process duration events', () async {
      final Iterable<TimelineEvent> events = durationData
          .trim()
          .split('\n')
          .map((String str) => TimelineEvent(jsonDecode(str)));

      final TimelineData timelineData = TimelineData();
      final TimelineThread thread =
          TimelineThread(timelineData, 'engine', 41219);
      timelineData.addThread(thread);

      final Future<TimelineThreadEvent> resultFuture =
          timelineData.onTimelineThreadEvent.first;

      events.forEach(timelineData.processTimelineEvent);

      final TimelineThreadEvent result = await resultFuture;

      expect(result.name, 'Engine::BeginFrame');
      final List<TimelineThreadEvent> children = result.children;
      expect(children, hasLength(8));
      expect(children[0].name, 'Animate');
      expect(children[1].name, 'Layout');
      expect(children[2].name, 'Compositing bits');
      expect(children[3].name, 'Paint');
      expect(children[4].name, 'Compositing');
      expect(children[5].name, 'Semantics');
      expect(children[6].name, 'Finalize tree');
      expect(children[7].name, 'Frame');
    });

    test('process async events', () async {
      final Iterable<TimelineEvent> events = asyncData
          .trim()
          .split('\n')
          .map((String str) => TimelineEvent(jsonDecode(str)));

      final TimelineData timelineData = TimelineData();
      final TimelineThread thread = TimelineThread(timelineData, 'dart', 41219);
      timelineData.addThread(thread);

      final Future<List<TimelineThreadEvent>> resultFuture =
          timelineData.onTimelineThreadEvent.take(2).toList();

      events.forEach(timelineData.processTimelineEvent);

      final List<TimelineThreadEvent> results = await resultFuture;

      expect(results, hasLength(2));

      expect(results[0].name, 'Frame Request Pending');
      expect(results[1].name, 'PipelineProduce');
    });
  });

  // TODO(devoncarew): Add test to locate frames.
}

const String durationData = '''
{"name":"Engine::BeginFrame","cat":"Embedder","tid":41219,"pid":81348,"ts":249012879086,"ph":"B","args":{}}
{"name":"Animate","cat":"Dart","tid":41219,"pid":81348,"ts":249012879135,"ph":"X","dur":27,"args":{"mode":"basic","isolateNumber":"891035574"}}
{"name":"Layout","cat":"Dart","tid":41219,"pid":81348,"ts":249012879190,"ph":"X","dur":25,"args":{"mode":"basic","isolateNumber":"891035574"}}
{"name":"Compositing bits","cat":"Dart","tid":41219,"pid":81348,"ts":249012879218,"ph":"X","dur":7,"args":{"isolateNumber":"891035574"}}
{"name":"Paint","cat":"Dart","tid":41219,"pid":81348,"ts":249012879227,"ph":"X","dur":6,"args":{"mode":"basic","isolateNumber":"891035574"}}
{"name":"Compositing","cat":"Dart","tid":41219,"pid":81348,"ts":249012879235,"ph":"X","dur":111,"args":{"mode":"basic","isolateNumber":"891035574"}}
{"name":"Semantics","cat":"Dart","tid":41219,"pid":81348,"ts":249012879349,"ph":"X","dur":23,"args":{"isolateNumber":"891035574"}}
{"name":"Finalize tree","cat":"Dart","tid":41219,"pid":81348,"ts":249012879373,"ph":"X","dur":24,"args":{"mode":"basic","isolateNumber":"891035574"}}
{"name":"Frame","cat":"Dart","tid":41219,"pid":81348,"ts":249012879119,"ph":"X","dur":292,"args":{"mode":"basic","isolateNumber":"891035574"}}
{"name":"Engine::BeginFrame","cat":"Embedder","tid":41219,"pid":81348,"ts":249012879470,"ph":"E","args":{}}
''';

const String asyncData = '''
{"name":"Frame Request Pending","cat":"Embedder","tid":41219,"pid":81348,"ts":250717377278,"ph":"b","id":"2cf","args":{}}
{"name":"Frame Request Pending","cat":"Embedder","tid":41219,"pid":81348,"ts":250717391754,"ph":"e","id":"2cf","args":{}}
{"name":"PipelineProduce","cat":"Embedder","tid":41219,"pid":81348,"ts":250717391755,"ph":"b","id":"2cf","args":{}}
{"name":"PipelineProduce","cat":"Embedder","tid":41219,"pid":81348,"ts":250717392000,"ph":"e","id":"2cf","args":{"isolateNumber":"891035574"}}
''';
