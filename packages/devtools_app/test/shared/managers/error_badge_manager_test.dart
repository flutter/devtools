// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/app_size/app_size_screen.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/inspector_shared/inspector_screen.dart';
import 'package:devtools_app/src/screens/logging/logging_screen.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_screen.dart';
import 'package:devtools_app/src/screens/network/network_screen.dart';
import 'package:devtools_app/src/screens/performance/performance_screen.dart';
import 'package:devtools_app/src/screens/profiler/profiler_screen.dart';
import 'package:devtools_app/src/shared/managers/error_badge_manager.dart';
import 'package:flutter_test/flutter_test.dart';

final supportedScreenIds = [
  InspectorScreen.id,
  PerformanceScreen.id,
  NetworkScreen.id,
];

final allScreenIds = [
  InspectorScreen.id,
  PerformanceScreen.id,
  ProfilerScreen.id,
  MemoryScreen.id,
  DebuggerScreen.id,
  NetworkScreen.id,
  LoggingScreen.id,
  AppSizeScreen.id,
];

void main() {
  late ErrorBadgeManager errorBadgeManager;

  group('ErrorBadgeManager', () {
    int getActiveErrorCount(screenId) =>
        errorBadgeManager.erroredItemsForPage(screenId).value.entries.length;

    setUp(() {
      errorBadgeManager = ErrorBadgeManager();
    });

    test('base state', () {
      for (final id in allScreenIds) {
        expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
      }
    });

    test('incrementBadgeCount only increments supported tabs', () {
      for (final id in allScreenIds) {
        expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
      }

      allScreenIds.forEach(errorBadgeManager.incrementBadgeCount);

      for (final id in allScreenIds) {
        if (supportedScreenIds.contains(id)) {
          expect(errorBadgeManager.errorCountNotifier(id).value, equals(1));
        } else {
          expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
        }
      }
    });

    test('clearErrorCount resets counts', () {
      allScreenIds.forEach(errorBadgeManager.incrementBadgeCount);

      for (final id in allScreenIds) {
        if (supportedScreenIds.contains(id)) {
          expect(errorBadgeManager.errorCountNotifier(id).value, equals(1));
        } else {
          expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
        }
      }

      allScreenIds.forEach(errorBadgeManager.clearErrorCount);

      for (final id in allScreenIds) {
        expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
      }
    });

    // TODO(https://github.com/flutter/devtools/issues/9105): This logic should
    // be moved to the inspector.
    test('appendError works for inspector screen only', () {
      for (final id in allScreenIds) {
        errorBadgeManager.appendError(id, DevToolsError('An error', id));
      }

      for (final id in allScreenIds) {
        if (id == InspectorScreen.id) {
          expect(getActiveErrorCount(id), equals(1));
        } else {
          expect(getActiveErrorCount(id), equals(0));
        }
      }
    });

    test('clearErrors resets counts and removes errors', () {
      expect(getActiveErrorCount(InspectorScreen.id), equals(0));
      expect(getActiveErrorCount(InspectorScreen.id), equals(0));

      errorBadgeManager.appendError(
        InspectorScreen.id,
        DevToolsError('An error', InspectorScreen.id),
      );

      expect(getActiveErrorCount(InspectorScreen.id), equals(1));
      expect(getActiveErrorCount(InspectorScreen.id), equals(1));

      errorBadgeManager.clearErrors(InspectorScreen.id);

      expect(getActiveErrorCount(InspectorScreen.id), equals(0));
      expect(getActiveErrorCount(InspectorScreen.id), equals(0));
    });
  });
}
