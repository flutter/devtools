// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('AccessibilityController', () {
    late AccessibilityController controller;

    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isFlutterWebAppNow,
      ).thenReturn(false);
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow,
      ).thenReturn(false);

      setGlobal(NotificationService, NotificationService());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);

      controller = AccessibilityController()..init();
    });

    test('initial state', () {
      expect(controller.brightness.value, BrightnessOverride.system);
    });

    test(
      'service extension state change updates controller brightness state',
      () {
        final fakeServiceExtensionManager =
            serviceConnection.serviceManager.serviceExtensionManager
                as FakeServiceExtensionManager;

        expect(controller.brightness.value, BrightnessOverride.system);

        // Simulate service extension state change from device to dark mode
        fakeServiceExtensionManager.fakeServiceExtensionStateChanged(
          brightnessMode.extension,
          'Brightness.dark',
        );
        expect(controller.brightness.value, BrightnessOverride.dark);

        // Simulate service extension state change from device to light mode
        fakeServiceExtensionManager.fakeServiceExtensionStateChanged(
          brightnessMode.extension,
          'Brightness.light',
        );
        expect(controller.brightness.value, BrightnessOverride.light);

        // Simulate service extension state change from device to system
        fakeServiceExtensionManager.fakeServiceExtensionStateChanged(
          brightnessMode.extension,
          'system',
        );
        expect(controller.brightness.value, BrightnessOverride.system);
      },
    );

    test(
      'setting controller brightness updates service extension state',
      () async {
        final fakeServiceExtensionManager =
            serviceConnection.serviceManager.serviceExtensionManager
                as FakeServiceExtensionManager;

        // Initial state
        expect(controller.brightness.value, BrightnessOverride.system);

        // Set to dark mode
        controller.brightness.value = BrightnessOverride.dark;

        // Wait for async operations to complete
        await Future<void>.delayed(Duration.zero);

        final darkState = fakeServiceExtensionManager
            .getServiceExtensionState(brightnessMode.extension)
            .value;
        expect(darkState.value, equals('Brightness.dark'));
        expect(darkState.enabled, isTrue);

        // Set to light mode
        controller.brightness.value = BrightnessOverride.light;
        await Future<void>.delayed(Duration.zero);

        final lightState = fakeServiceExtensionManager
            .getServiceExtensionState(brightnessMode.extension)
            .value;
        expect(lightState.value, equals('Brightness.light'));
        expect(lightState.enabled, isTrue);

        // Set to system
        controller.brightness.value = BrightnessOverride.system;
        await Future<void>.delayed(Duration.zero);

        final systemState = fakeServiceExtensionManager
            .getServiceExtensionState(brightnessMode.extension)
            .value;
        expect(systemState.value, equals('system'));
        expect(systemState.enabled, isFalse);
      },
    );
  });
}
