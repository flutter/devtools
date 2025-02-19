// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockDevToolsScreenController extends Mock
    implements DevToolsScreenController {}

class MockOfflineDataController extends Mock implements OfflineDataController {
  @override
  ValueNotifier<bool> showingOfflineData = ValueNotifier<bool>(false);
}

void main() {
  group('ScreenControllers', () {
    late ScreenControllers screenControllers;
    late MockOfflineDataController offlineDataController;

    setUp(() {
      screenControllers = ScreenControllers();
      offlineDataController = MockOfflineDataController();
      offlineDataController.showingOfflineData.value = false;
      setGlobal(OfflineDataController, offlineDataController);
    });

    test('register and lookup reflects offline state', () {
      final controller1 = MockDevToolsScreenController();
      final controller2 = MockDevToolsScreenController();

      screenControllers.register<MockDevToolsScreenController>(
        () => controller1,
      );
      screenControllers.register<MockDevToolsScreenController>(
        () => controller2,
        offline: true,
      );

      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        controller1,
      );

      offlineDataController.showingOfflineData.value = true;
      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        controller2,
      );

      offlineDataController.showingOfflineData.value = false;
      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        controller1,
      );
    });

    test('register does not initialize controller', () {
      final controller1 = MockDevToolsScreenController();
      final controller2 = MockDevToolsScreenController();

      screenControllers.register<MockDevToolsScreenController>(
        () => controller1,
      );
      screenControllers.register<MockDevToolsScreenController>(
        () => controller2,
        offline: true,
      );

      verifyNever(controller1.init());
      verifyNever(controller2.init());
    });

    test('register overwrites existing controller', () {
      final controller1 = MockDevToolsScreenController();
      final controller2 = MockDevToolsScreenController();
      screenControllers.register<MockDevToolsScreenController>(
        () => controller1,
      );
      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        controller1,
      );
      verifyNever(controller1.dispose());

      screenControllers.register<MockDevToolsScreenController>(
        () => controller2,
      );
      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        controller2,
      );
      verify(controller1.dispose()).called(1);
      verifyNever(controller2.dispose());

      offlineDataController.showingOfflineData.value = true;
      final offlineController1 = MockDevToolsScreenController();
      final offlineController2 = MockDevToolsScreenController();
      screenControllers.register<MockDevToolsScreenController>(
        () => offlineController1,
        offline: true,
      );
      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        offlineController1,
      );
      verifyNever(offlineController1.dispose());

      screenControllers.register<MockDevToolsScreenController>(
        () => offlineController2,
        offline: true,
      );
      expect(
        screenControllers.lookup<MockDevToolsScreenController>(),
        offlineController2,
      );
      verify(offlineController1.dispose()).called(1);
      verifyNever(offlineController2.dispose());
    });

    test('disposeConnectedControllers', () {
      final controller1 = MockDevToolsScreenController();
      screenControllers.register<MockDevToolsScreenController>(
        () => controller1,
      );
      screenControllers
          .lookup<MockDevToolsScreenController>(); // Force initialization.
      verify(controller1.init()).called(1);

      screenControllers.disposeConnectedControllers();
      verify(controller1.dispose()).called(1);
      expect(screenControllers.controllers, isEmpty);
    });

    test('disposeOfflineControllers', () {
      final controller1 = MockDevToolsScreenController();
      screenControllers.register<MockDevToolsScreenController>(
        () => controller1,
        offline: true,
      );
      offlineDataController.showingOfflineData.value = true;
      screenControllers.lookup<MockDevToolsScreenController>(); // Force init.
      verify(controller1.init()).called(1);

      screenControllers.disposeOfflineControllers();
      verify(controller1.dispose()).called(1);
      expect(screenControllers.offlineControllers, isEmpty);
    });

    test('lookup throws if controller is not registered', () {
      expect(
        () => screenControllers.lookup<MockDevToolsScreenController>(),
        throwsA(isA<AssertionError>()),
      );

      offlineDataController.showingOfflineData.value = true;
      expect(
        () => screenControllers.lookup<MockDevToolsScreenController>(),
        throwsA(isA<AssertionError>()),
      );
    });

    test('lazy initialization', () {
      final controller = MockDevToolsScreenController();
      screenControllers.register<MockDevToolsScreenController>(
        () => controller,
      );

      verifyNever(controller.init()); // Not initialized yet

      screenControllers.lookup<MockDevToolsScreenController>();
      verify(controller.init()).called(1); // Now it's initialized
    });
  });
}
