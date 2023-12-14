// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import '../../../test_infra/test_data/performance.dart';

void main() {
  final ServiceConnectionManager fakeServiceManager =
      FakeServiceConnectionManager(
    service: FakeServiceManager.createFakeService(
      timelineData: Timeline.parse(testTimelineJson)!,
    ),
  );

  group('$LegacyTimelineEventsController', () {
    late TimelineEventsController eventsController;

    setUp(() {
      when(fakeServiceManager.serviceManager.connectedApp!.isProfileBuild)
          .thenAnswer((realInvocation) => Future.value(false));
      final initializedCompleter = Completer<bool>();
      initializedCompleter.complete(true);
      when(fakeServiceManager.serviceManager.connectedApp!.initialized)
          .thenReturn(initializedCompleter);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineModeController, OfflineModeController());

      final performanceController =
          createMockPerformanceControllerWithDefaults();
      eventsController = TimelineEventsController(performanceController);
      final flutterFramesController = MockFlutterFramesController();
      when(performanceController.timelineEventsController)
          .thenReturn(eventsController);
      when(performanceController.flutterFramesController)
          .thenReturn(flutterFramesController);
      when(flutterFramesController.hasUnassignedFlutterFrame(any))
          .thenReturn(false);
    });
    test('matchesForSearch', () async {
      // Verify an empty list is returned for bad input.
      expect(eventsController.legacyController.matchesForSearch(''), isEmpty);

      await eventsController.clearData();
      expect(eventsController.data!.timelineEvents, isEmpty);
      expect(
        eventsController.legacyController.matchesForSearch('test'),
        isEmpty,
      );

      eventsController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());
      expect(
        eventsController.legacyController.matchesForSearch('test'),
        isEmpty,
      );

      final matches =
          eventsController.legacyController.matchesForSearch('frame');
      expect(matches.length, equals(4));
      expect(matches[0].name, equals('Animator::BeginFrame'));
      expect(matches[1].name, equals('Framework Workload'));
      expect(matches[2].name, equals('Engine::BeginFrame'));
      expect(matches[3].name, equals('Frame'));
    });

    test('search query searches through previous matches', () async {
      await eventsController.clearData();
      eventsController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());

      final data = eventsController.data!;

      eventsController.legacyController.search = 'fram';
      var matches = eventsController.legacyController.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        data.timelineEvents,
        matches,
      );

      // Add another timeline event to verify that this event is not searched
      // for matches.
      eventsController.addTimelineEvent(goldenUiTimelineEvent..deepCopy());

      eventsController.legacyController.search = 'frame';
      matches = eventsController.legacyController.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        data.timelineEvents,
        matches,
      );

      // Verify that more matches are found without `searchPreviousMatches` set
      // to true.
      eventsController.legacyController.search = '';
      eventsController.legacyController.search = 'frame';
      matches = eventsController.legacyController.searchMatches.value;
      expect(matches.length, equals(8));
      verifyIsSearchMatchForTreeData<TimelineEvent>(
        data.timelineEvents,
        matches,
      );
    });
  });
}
