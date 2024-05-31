// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

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
    });

    test('has value', () {
      expect(controller.darkModeTheme.value, isNotNull);
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
  });

  // TODO(https://github.com/flutter/devtools/issues/4342): Add more tests.
  group('$InspectorPreferencesController', () {
    late InspectorPreferencesController controller;
    late FlutterTestStorage storage;

    void updateMainIsolateRootLibrary(String? rootLibrary) {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(
          rootLibrary: rootLibrary,
        ),
      );
    }

    setUp(() {
      setGlobal(Storage, storage = FlutterTestStorage());
      controller = InspectorPreferencesController();
    });

    group('hoverEvalMode', () {
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
    });

    group(
      'infers the pub root directory based on the main isolate\'s root library',
      () {
        final rootLibToExpectedPubRoot = {
          'test_dir/fake_app/lib/main.dart': 'test_dir/fake_app/',
          'my_user/google3/dart_apps/test_app/lib/main.dart': '/dart_apps/',
          'my_user/google3/third_party/dart/dart_apps/test_app/lib/main.dart':
              '/third_party/dart/',
        };

        for (final MapEntry(
              key: rootLib,
              value: expectedPubRoot,
            ) in rootLibToExpectedPubRoot.entries) {
          test(
            '$rootLib -> $expectedPubRoot',
            () async {
              updateMainIsolateRootLibrary(rootLib);
              await controller.handleConnectionToNewService();
              final directories = controller.pubRootDirectories.value;

              expect(directories, equals([expectedPubRoot]));
            },
          );
        }
      },
    );

    group('Caching custom pub root directories', () {
      final customPubRootDirectories = [
        'test_dir/fake_app/custom_dir1',
        'test_dir/fake_app/custom_dir2',
      ];

      setUp(() async {
        updateMainIsolateRootLibrary('test_dir/fake_app/lib/main.dart');
        await controller.handleConnectionToNewService();
        await controller.addPubRootDirectories(
          customPubRootDirectories,
          shouldCache: true,
        );
      });

      test(
        'fetches custom pub root directories from the local cache',
        () {
          final directories = controller.pubRootDirectories.value;

          expect(
            directories,
            containsAll(customPubRootDirectories),
          );
        },
      );

      test(
        'custom pub root directories are cached across multiple connections',
        () async {
          var directories = controller.pubRootDirectories.value;
          var cachedDirectories =
              await controller.readCachedPubRootDirectories();

          expect(
            directories,
            containsAll(customPubRootDirectories),
          );
          expect(
            cachedDirectories,
            containsAll(customPubRootDirectories),
          );

          await controller.handleConnectionToNewService();
          directories = controller.pubRootDirectories.value;
          cachedDirectories = await controller.readCachedPubRootDirectories();

          expect(
            directories,
            containsAll(customPubRootDirectories),
          );
          expect(cachedDirectories, containsAll(customPubRootDirectories));
        },
      );

      test(
        'adding more directories to cache doesn\'t overwrite pre-existing values',
        () async {
          await controller.addPubRootDirectories(
            ['test_dir/fake_app/custom_dir3'],
            shouldCache: true,
          );

          final cachedDirectories =
              await controller.readCachedPubRootDirectories();

          expect(
            cachedDirectories,
            containsAll([
              ...customPubRootDirectories,
              'test_dir/fake_app/custom_dir3',
            ]),
          );
        },
      );

      test(
        'removing directories from cache removes the correct values',
        () async {
          const notRemoved = 'test_dir/fake_app/custom_dir1';
          const removed = 'test_dir/fake_app/custom_dir2';
          var cachedDirectories =
              await controller.readCachedPubRootDirectories();

          expect(cachedDirectories, containsAll([notRemoved, removed]));

          await controller.removePubRootDirectories([removed]);
          cachedDirectories = await controller.readCachedPubRootDirectories();

          expect(
            cachedDirectories,
            isNot(contains(removed)),
          );
          expect(
            cachedDirectories,
            contains(notRemoved),
          );
        },
      );

      test(
        'directories includes inferred directory as well',
        () {
          final directories = controller.pubRootDirectories.value;

          expect(
            directories,
            contains('test_dir/fake_app/'),
          );
        },
      );

      test(
        'does not save inferred directory to local cache',
        () async {
          final cachedDirectories =
              await controller.readCachedPubRootDirectories();

          expect(cachedDirectories, isNot(contains('test_dir/fake_app/')));
        },
      );

      test(
        'directories added with "no caching" specified are not cached',
        () async {
          await controller.addPubRootDirectories(
            ['test_dir/fake_app/do_not_cache_dir'],
          );
          final cachedDirectories =
              await controller.readCachedPubRootDirectories();

          expect(
            cachedDirectories,
            isNot(contains('test_dir/fake_app/do_not_cache_dir')),
          );
        },
      );
    });

    test('Flutter pub root is removed from cache on app connection', () async {
      updateMainIsolateRootLibrary('test_dir/fake_app/lib/main.dart');
      await storage.setValue(
        'inspector.customPubRootDirectories_myPackage',
        jsonEncode(
          [
            'flutter_dir/flutter/packages/flutter',
            'test_dir/fake_app/custom_dir1',
          ],
        ),
      );
      await controller.handleConnectionToNewService();
      final cachedDirectories = await controller.readCachedPubRootDirectories();

      expect(
        cachedDirectories,
        isNot(contains('flutter_dir/flutter/packages/flutter')),
      );
      expect(
        cachedDirectories,
        contains('test_dir/fake_app/custom_dir1'),
      );
    });

    test(
      'Flutter pub root is removed from cache across multiple app connections',
      () async {
        updateMainIsolateRootLibrary('test_dir/fake_app/lib/main.dart');
        await storage.setValue(
          'inspector.customPubRootDirectories_myPackage',
          jsonEncode(
            [
              'flutter_dir/flutter/packages/flutter',
              'test_dir/fake_app/custom_dir1',
            ],
          ),
        );
        await controller.handleConnectionToNewService();
        var cachedDirectories = await controller.readCachedPubRootDirectories();

        expect(
          cachedDirectories,
          isNot(contains('flutter_dir/flutter/packages/flutter')),
        );
        expect(
          cachedDirectories,
          contains('test_dir/fake_app/custom_dir1'),
        );

        await storage.setValue(
          'inspector.customPubRootDirectories_myPackage',
          jsonEncode(
            [
              'flutter_dir/flutter/packages/flutter',
              'test_dir/fake_app/custom_dir2',
            ],
          ),
        );
        await controller.handleConnectionToNewService();
        cachedDirectories = await controller.readCachedPubRootDirectories();

        expect(
          cachedDirectories,
          isNot(contains('flutter_dir/flutter/packages/flutter')),
        );
        expect(
          cachedDirectories,
          contains('test_dir/fake_app/custom_dir2'),
        );
      },
    );
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
      for (final key in storage.values.keys) {
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

  group('$PerformancePreferencesController', () {
    late PerformancePreferencesController controller;
    late FlutterTestStorage storage;

    setUp(() async {
      setGlobal(Storage, storage = FlutterTestStorage());
      controller = PerformancePreferencesController();
      await controller.init();
    });

    test('has expected default values', () {
      expect(controller.showFlutterFramesChart.value, true);
      expect(controller.includeCpuSamplesInTimeline.value, false);
    });

    test('stores values and reads them on init', () async {
      storage.values.clear();

      // Remember original values.
      final showFramesChart = controller.showFlutterFramesChart.value;
      final includeCpuSamplesInTimeline =
          controller.includeCpuSamplesInTimeline.value;

      // Flip the values in controller.
      controller.showFlutterFramesChart.value = !showFramesChart;
      controller.includeCpuSamplesInTimeline.value =
          !includeCpuSamplesInTimeline;

      // Check the values are stored.
      expect(storage.values, hasLength(2));

      // Reload the values from storage.
      await controller.init();

      // Check they did not change back to default.
      expect(
        controller.showFlutterFramesChart.value,
        !showFramesChart,
      );
      expect(
        controller.includeCpuSamplesInTimeline.value,
        !includeCpuSamplesInTimeline,
      );

      // Flip the values in storage.
      for (final key in storage.values.keys) {
        storage.values[key] = (!(storage.values[key] == 'true')).toString();
      }

      // Reload the values from storage.
      await controller.init();

      // Check they flipped values are loaded.
      expect(
        controller.showFlutterFramesChart.value,
        showFramesChart,
      );
      expect(
        controller.includeCpuSamplesInTimeline.value,
        includeCpuSamplesInTimeline,
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
      for (final key in storage.values.keys) {
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
