// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import '../test_infra/flutter_test_environment.dart';

void main() {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  group('TimelineStreamManager', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test(
      'timeline streams initialized on vm service opened',
      () async {
        await env.setupEnvironment();

        // Await a short delay to make sure the timelineStreamManager is done
        // initializing.
        await delay();

        expect(serviceManager.service, equals(env.service));
        expect(serviceManager.timelineStreamManager, isNotNull);
        expect(serviceManager.timelineStreamManager.basicStreams, isNotEmpty);
        expect(
          serviceManager.timelineStreamManager.advancedStreams,
          isNotEmpty,
        );

        await env.tearDownEnvironment();
      },
      timeout: const Timeout.factor(4),
    );

    test(
      'notifies on stream change',
      () async {
        await env.setupEnvironment();

        final initialStreams =
            serviceManager.timelineStreamManager.recordedStreams;
        expect(
          initialStreams.map((stream) => stream.name).toList(),
          equals(['Dart', 'Embedder', 'GC']),
        );

        await serviceManager.service!.setVMTimelineFlags([
          TimelineStreamManager.apiTimelineStream,
          TimelineStreamManager.compilerTimelineStream,
          TimelineStreamManager.isolateTimelineStream,
        ]);
        final newStreams = serviceManager.timelineStreamManager.recordedStreams;
        expect(
          newStreams.map((stream) => stream.name).toList(),
          equals(['API', 'Compiler', 'Isolate']),
        );

        await env.tearDownEnvironment();
      },
      timeout: const Timeout.factor(4),
    );
  });
}
