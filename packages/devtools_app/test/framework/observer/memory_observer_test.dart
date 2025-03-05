// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/observer/memory_observer.dart';
import 'package:devtools_app/src/shared/analytics/constants.dart' as gac;
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/primitives/byte_utils.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    setUp(() {
      measurementComplete = Completer();
      FeatureFlags.memoryObserver = true;
      observer = MemoryObserver(
        debugMeasureUsageInBytes: testMeasureMemoryUsage,
        pollingDuration: const Duration(milliseconds: 1),
      );
      setGlobal(BannerMessagesController, BannerMessagesController());
    });

    tearDown(() {
      observer.dispose();
    });

    test(
      'does not add banner message when memory limit is not reached',
      () async {
        memoryUsageBytes =
            convertBytes(1, from: ByteUnit.gb, to: ByteUnit.byte).round();
        observer.init();
        await measurementComplete.future;

        // If this value is not null, then the call to
        // `bannerMessages.messagesForScreen` below will lookup messages for the
        // wrong screen, since `DevToolsRouterDelegate.currentPage` would be
        // used instead of `gac.devToolsMain`.
        expect(DevToolsRouterDelegate.currentPage, isNull);

        final messages =
            bannerMessages.messagesForScreen(gac.devToolsMain).value;
        expect(messages, isEmpty);
      },
    );

    test('adds banner message when memory limit is reached', () async {
      memoryUsageBytes =
          convertBytes(3.1, from: ByteUnit.gb, to: ByteUnit.byte).round();
      observer.init();
      await measurementComplete.future;

      // If this value is not null, then the call to
      // `bannerMessages.messagesForScreen` below will lookup messages for the
      // wrong screen, since `DevToolsRouterDelegate.currentPage` would be
      // used instead of `gac.devToolsMain`.
      expect(DevToolsRouterDelegate.currentPage, isNull);

      final messages = bannerMessages.messagesForScreen(gac.devToolsMain).value;
      expect(messages, isNotEmpty);
    });
  });
}
