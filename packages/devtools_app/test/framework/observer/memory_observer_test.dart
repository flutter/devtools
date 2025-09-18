// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/observer/memory_observer.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/primitives/byte_utils.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOfflineDataController offlineDataController;

  group('$MemoryObserver', () {
    late MemoryObserver observer;

    int memoryUsageBytes = 0;

    var measurementComplete = Completer<void>();

    Future<int?> testMeasureMemoryUsage() async {
      unawaited(
        Future.delayed(
          Duration.zero,
          // Complete after releasing the UI thread to allow the memory observer
          // logic to complete during the async gap.
          () => measurementComplete.complete(),
        ),
      );
      return memoryUsageBytes;
    }

    setUpAll(() {
      FeatureFlags.memoryObserver.setValueForTests(true);
    });

    setUp(() {
      measurementComplete = Completer();
      observer = MemoryObserver(
        debugMeasureUsageInBytes: testMeasureMemoryUsage,
        pollingDuration: const Duration(milliseconds: 1),
      );
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(BannerMessagesController, BannerMessagesController());
      offlineDataController = MockOfflineDataController();
      offlineDataController.showingOfflineData.value = false;
      setGlobal(OfflineDataController, offlineDataController);
    });

    tearDown(() {
      observer.dispose();
    });

    tearDownAll(() {
      FeatureFlags.memoryObserver.setValueForTests(false);
    });

    test(
      'does not add banner message when memory limit is not reached',
      () async {
        memoryUsageBytes = convertBytes(
          1,
          from: ByteUnit.gb,
          to: ByteUnit.byte,
        ).round();
        observer.init();
        await measurementComplete.future;

        // If this value is not null, then the call to
        // `bannerMessages.messagesForScreen` below will lookup messages for the
        // wrong screen, since `DevToolsRouterDelegate.currentPage` would be
        // used instead of `gac.devToolsMain`.
        expect(DevToolsRouterDelegate.currentPage, isNull);

        final messages = bannerMessages
            .messagesForScreen(universalScreenId)
            .value;
        expect(messages, isEmpty);
      },
    );

    test('adds banner message when memory limit is reached', () async {
      memoryUsageBytes = convertBytes(
        3.1,
        from: ByteUnit.gb,
        to: ByteUnit.byte,
      ).round();
      observer.init();
      await measurementComplete.future;

      // If this value is not null, then the call to
      // `bannerMessages.messagesForScreen` below will lookup messages for the
      // wrong screen, since `DevToolsRouterDelegate.currentPage` would be
      // used instead of `gac.devToolsMain`.
      expect(DevToolsRouterDelegate.currentPage, isNull);

      final messages = bannerMessages
          .messagesForScreen(universalScreenId)
          .value;
      expect(messages, isNotEmpty);
    });

    group('reduce memory', () {
      late FakeScreenController1 screenController1;
      late FakeScreenController2 screenController2;

      setUp(() {
        screenController1 = FakeScreenController1();
        screenController2 = FakeScreenController2();
        setGlobal(ScreenControllers, ScreenControllers());
        screenControllers.register<FakeScreenController1>(
          () => screenController1,
        );
        screenControllers.register<FakeScreenController2>(
          () => screenController2,
        );
      });

      Future<int?> testMeasureMemoryUsage() async => memoryUsageBytes;

      test(
        'fully releases other screens and partially releases the current screen',
        () async {
          // Lookups to force initialization.
          screenControllers.lookup<FakeScreenController1>();
          screenControllers.lookup<FakeScreenController2>();
          DevToolsRouterDelegate.currentPage = screenController1.screenId;

          memoryUsageBytes = convertBytes(
            3.1,
            from: ByteUnit.gb,
            to: ByteUnit.byte,
          ).round();
          var result = await MemoryObserver.reduceMemory(
            debugMeasureUsageInBytes: testMeasureMemoryUsage,
          );
          expect(result.success, isFalse);
          expect(screenController1.releaseMemoryCallCount, 1);
          expect(screenController1.partialReleaseMemoryCallCount, 1);
          expect(screenController2.releaseMemoryCallCount, 1);
          expect(screenController2.partialReleaseMemoryCallCount, 0);

          memoryUsageBytes = convertBytes(
            1,
            from: ByteUnit.gb,
            to: ByteUnit.byte,
          ).round();
          result = await MemoryObserver.reduceMemory(
            debugMeasureUsageInBytes: testMeasureMemoryUsage,
          );
          expect(result.success, isTrue);
          expect(screenController1.releaseMemoryCallCount, equals(1));
          expect(screenController1.partialReleaseMemoryCallCount, equals(1));
          expect(screenController2.releaseMemoryCallCount, equals(2));
          expect(screenController2.partialReleaseMemoryCallCount, equals(0));
        },
      );

      test('skips uninitialized screen controllers', () async {
        DevToolsRouterDelegate.currentPage = screenController1.screenId;

        memoryUsageBytes = convertBytes(
          3.1,
          from: ByteUnit.gb,
          to: ByteUnit.byte,
        ).round();
        var result = await MemoryObserver.reduceMemory(
          debugMeasureUsageInBytes: testMeasureMemoryUsage,
        );
        expect(result.success, isFalse);
        expect(screenController1.releaseMemoryCallCount, 0);
        expect(screenController1.partialReleaseMemoryCallCount, 0);
        expect(screenController2.releaseMemoryCallCount, 0);
        expect(screenController2.partialReleaseMemoryCallCount, 0);

        // Lookup to force initialization.
        screenControllers.lookup<FakeScreenController1>();

        memoryUsageBytes = convertBytes(
          3.1,
          from: ByteUnit.gb,
          to: ByteUnit.byte,
        ).round();
        result = await MemoryObserver.reduceMemory(
          debugMeasureUsageInBytes: testMeasureMemoryUsage,
        );
        expect(result.success, isFalse);
        expect(screenController1.releaseMemoryCallCount, 1);
        expect(screenController1.partialReleaseMemoryCallCount, 1);
        expect(screenController2.releaseMemoryCallCount, 0);
        expect(screenController2.partialReleaseMemoryCallCount, 0);
      });
    });
  });
}

class FakeScreenController1 extends DevToolsScreenController {
  @override
  String get screenId => 'fake-screen-1';

  int releaseMemoryCallCount = 0;
  int partialReleaseMemoryCallCount = 0;

  @override
  Future<void> releaseMemory({bool partial = false}) async {
    releaseMemoryCallCount++;
    if (partial) {
      partialReleaseMemoryCallCount++;
    }
  }
}

class FakeScreenController2 extends DevToolsScreenController {
  @override
  String get screenId => 'fake-screen-2';

  int releaseMemoryCallCount = 0;
  int partialReleaseMemoryCallCount = 0;

  @override
  Future<void> releaseMemory({bool partial = false}) async {
    releaseMemoryCallCount++;
    if (partial) {
      partialReleaseMemoryCallCount++;
    }
  }
}
