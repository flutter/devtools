// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_storage.dart';

void main() {
  setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());

  group('$PreferencesController', () {
    late PreferencesController controller;

    setUp(() {
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      controller = PreferencesController();
    });

    test('has subcontrollers initialized', () {
      expect(controller.memory, isNotNull);
      expect(controller.inspector, isNotNull);
      expect(controller.cpuProfiler, isNotNull);
    });

    test('has value', () {
      expect(controller.darkModeTheme.value, isNotNull);
      expect(controller.denseModeEnabled.value, isNotNull);
    });

    test('toggleDarkModeTheme', () {
      bool valueChanged = false;
      final originalValue = controller.darkModeTheme.value;

      controller.darkModeTheme.addListener(() {
        valueChanged = true;
      });

      controller.toggleDarkModeTheme(!controller.darkModeTheme.value);
      expect(valueChanged, isTrue);
      expect(controller.darkModeTheme.value, isNot(originalValue));
    });

    test('toggleVmDeveloperMode', () {
      bool valueChanged = false;
      final originalValue = controller.vmDeveloperModeEnabled.value;

      controller.vmDeveloperModeEnabled.addListener(() {
        valueChanged = true;
      });

      controller
          .toggleVmDeveloperMode(!controller.vmDeveloperModeEnabled.value);
      expect(valueChanged, isTrue);
      expect(controller.vmDeveloperModeEnabled.value, isNot(originalValue));
    });

    test('toggleDenseMode', () {
      bool valueChanged = false;
      final originalValue = controller.denseModeEnabled.value;

      controller.denseModeEnabled.addListener(() {
        valueChanged = true;
      });

      controller.toggleDenseMode(!controller.denseModeEnabled.value);
      expect(valueChanged, isTrue);
      expect(controller.denseModeEnabled.value, isNot(originalValue));
    });
  });

  group('$InspectorPreferencesController', () {
    group('hoverEvalMode', () {
      late InspectorPreferencesController controller;
      late FlutterTestStorage storage;

      setUp(() {
        setGlobal(Storage, storage = FlutterTestStorage());
        controller = InspectorPreferencesController();
      });

      test('default value equals inspector service default value', () async {
        await controller.init();
        expect(
          controller.hoverEvalModeEnabled.value,
          serviceConnection.inspectorService!.hoverEvalModeEnabledByDefault,
        );
      });

      test('can be updated', () async {
        await controller.init();

        var valueChanged = false;
        final newHoverModeValue = !controller.hoverEvalModeEnabled.value;
        controller.hoverEvalModeEnabled.addListener(() {
          valueChanged = true;
        });

        controller.setHoverEvalMode(newHoverModeValue);

        final storedHoverModeValue =
            await storage.getValue('inspector.hoverEvalMode');
        expect(valueChanged, isTrue);
        expect(controller.hoverEvalModeEnabled.value, newHoverModeValue);
        expect(
          storedHoverModeValue,
          newHoverModeValue.toString(),
        );
      });
      // TODO(https://github.com/flutter/devtools/issues/4342): make inspector
      // preferences testable, then test it
    });
  });

  group('$MemoryPreferencesController', () {
    late MemoryPreferencesController controller;
    late FlutterTestStorage storage;

    setUp(() async {
      setGlobal(Storage, storage = FlutterTestStorage());
      controller = MemoryPreferencesController();
      await controller.init();
    });

    test('stores values and reads them on init', () async {
      storage.values.clear();

      // Remember original values.
      final originalAndroidCollection =
          controller.androidCollectionEnabled.value;

      // Flip the values in controller.
      controller.androidCollectionEnabled.value = !originalAndroidCollection;

      // Check the values are stored.
      expect(storage.values, hasLength(1));

      // Reload the values from storage.
      await controller.init();

      // Check they did not change back to default.
      expect(
        controller.androidCollectionEnabled.value,
        !originalAndroidCollection,
      );

      // Flip the values in storage.
      for (var key in storage.values.keys) {
        storage.values[key] = (!(storage.values[key] == 'true')).toString();
      }

      // Reload the values from storage.
      await controller.init();

      // Check they flipped values are loaded.
      expect(
        controller.androidCollectionEnabled.value,
        originalAndroidCollection,
      );
    });
  });

  group('$CpuProfilerPreferencesController', () {
    late CpuProfilerPreferencesController controller;
    late FlutterTestStorage storage;

    setUp(() async {
      setGlobal(Storage, storage = FlutterTestStorage());
      controller = CpuProfilerPreferencesController();
      await controller.init();
    });

    test('has expected default values', () {
      expect(controller.displayTreeGuidelines.value, isFalse);
    });

    test('stores values and reads them on init', () async {
      storage.values.clear();

      // Remember original values.
      final displayTreeGuidelines = controller.displayTreeGuidelines.value;

      // Flip the values in controller.
      controller.displayTreeGuidelines.value = !displayTreeGuidelines;

      // Check the values are stored.
      expect(storage.values, hasLength(1));

      // Reload the values from storage.
      await controller.init();

      // Check they did not change back to default.
      expect(
        controller.displayTreeGuidelines.value,
        !displayTreeGuidelines,
      );

      // Flip the values in storage.
      for (var key in storage.values.keys) {
        storage.values[key] = (!(storage.values[key] == 'true')).toString();
      }

      // Reload the values from storage.
      await controller.init();

      // Check they flipped values are loaded.
      expect(
        controller.displayTreeGuidelines.value,
        displayTreeGuidelines,
      );
    });
  });

  group('$PerformancePreferencesController', () {
    late PerformancePreferencesController controller;
    late FlutterTestStorage storage;

    setUp(() async {
      setGlobal(Storage, storage = FlutterTestStorage());
      controller = PerformancePreferencesController();
      await controller.init();
    });

    test('has expected default values', () {
      expect(controller.showFlutterFramesChart.value, isTrue);
    });

    test('stores values and reads them on init', () async {
      storage.values.clear();

      // Remember original values.
      final showFramesChart = controller.showFlutterFramesChart.value;

      // Flip the values in controller.
      controller.showFlutterFramesChart.value = !showFramesChart;

      // Check the values are stored.
      expect(storage.values, hasLength(1));

      // Reload the values from storage.
      await controller.init();

      // Check they did not change back to default.
      expect(
        controller.showFlutterFramesChart.value,
        !showFramesChart,
      );

      // Flip the values in storage.
      for (var key in storage.values.keys) {
        storage.values[key] = (!(storage.values[key] == 'true')).toString();
      }

      // Reload the values from storage.
      await controller.init();

      // Check they flipped values are loaded.
      expect(
        controller.showFlutterFramesChart.value,
        showFramesChart,
      );
    });
  });

  group('$ExtensionsPreferencesController', () {
    late ExtensionsPreferencesController controller;
    late FlutterTestStorage storage;

    setUp(() async {
      setGlobal(Storage, storage = FlutterTestStorage());
      controller = ExtensionsPreferencesController();
      await controller.init();
    });

    test('has expected default values', () {
      expect(controller.showOnlyEnabledExtensions.value, isFalse);
    });

    test('stores values and reads them on init', () async {
      storage.values.clear();

      // Remember original values.
      final showOnlyEnabled = controller.showOnlyEnabledExtensions.value;

      // Flip the values in controller.
      controller.showOnlyEnabledExtensions.value = !showOnlyEnabled;

      // Check the values are stored.
      expect(storage.values, hasLength(1));

      // Reload the values from storage.
      await controller.init();

      // Check they did not change back to default.
      expect(
        controller.showOnlyEnabledExtensions.value,
        !showOnlyEnabled,
      );

      // Flip the values in storage.
      for (var key in storage.values.keys) {
        storage.values[key] = (!(storage.values[key] == 'true')).toString();
      }

      // Reload the values from storage.
      await controller.init();

      // Check they flipped values are loaded.
      expect(
        controller.showOnlyEnabledExtensions.value,
        showOnlyEnabled,
      );
    });
  });
}
