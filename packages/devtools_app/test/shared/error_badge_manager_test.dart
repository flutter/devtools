// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/app_size/app_size_screen.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/inspector/inspector_screen.dart';
import 'package:devtools_app/src/screens/logging/logging_screen.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_screen.dart';
import 'package:devtools_app/src/screens/network/network_screen.dart';
import 'package:devtools_app/src/screens/performance/performance_screen.dart';
import 'package:devtools_app/src/screens/profiler/profiler_screen.dart';
import 'package:devtools_app/src/shared/error_badge_manager.dart';
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

    test('clearErrors resets counts', () {
      allScreenIds.forEach(errorBadgeManager.incrementBadgeCount);

      for (final id in allScreenIds) {
        if (supportedScreenIds.contains(id)) {
          expect(errorBadgeManager.errorCountNotifier(id).value, equals(1));
        } else {
          expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
        }
      }

      allScreenIds.forEach(errorBadgeManager.clearErrors);

      for (final id in allScreenIds) {
        expect(errorBadgeManager.errorCountNotifier(id).value, equals(0));
      }
    });
  });
}
