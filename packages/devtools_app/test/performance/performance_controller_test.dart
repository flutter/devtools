// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// TODO(kenz): add better test coverage for [PerformanceController].

void main() {
  late PerformanceController controller;
  late MockServiceConnectionManager mockServiceManager;

  group('$PerformanceController', () {
    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      mockServiceManager = MockServiceConnectionManager();
      final connectedApp = MockConnectedApp();
      mockConnectedApp(
        connectedApp,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      when(mockServiceManager.connectedApp).thenReturn(connectedApp);
      when(mockServiceManager.connectedState)
          .thenReturn(ValueNotifier(const ConnectedState(true)));
      setGlobal(ServiceConnectionManager, mockServiceManager);
      offlineController.enterOfflineMode(
        offlineApp: serviceManager.connectedApp!,
      );
      controller = PerformanceController();
    });

    test('setActiveFeature', () async {
      expect(controller.flutterFramesController.isActiveFeature, isFalse);
      expect(controller.timelineEventsController.isActiveFeature, isFalse);
      expect(controller.rasterStatsController.isActiveFeature, isFalse);

      await controller.setActiveFeature(controller.timelineEventsController);
      expect(controller.flutterFramesController.isActiveFeature, isTrue);
      expect(controller.timelineEventsController.isActiveFeature, isTrue);
      expect(controller.rasterStatsController.isActiveFeature, isFalse);

      await controller.setActiveFeature(controller.rasterStatsController);
      expect(controller.flutterFramesController.isActiveFeature, isTrue);
      expect(controller.timelineEventsController.isActiveFeature, isFalse);
      expect(controller.rasterStatsController.isActiveFeature, isTrue);
    });
  });
}
