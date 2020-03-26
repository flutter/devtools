// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/banner_messages.dart';
import 'package:devtools_app/src/flutter/controllers.dart';
import 'package:devtools_app/src/flutter/notifications.dart';
import 'package:devtools_app/src/flutter/scaffold.dart';
import 'package:devtools_app/src/flutter/theme.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/memory/flutter/memory_controller.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/timeline/flutter/timeline_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import '../support/mocks.dart';

/// Wraps [widget] with the build context it needs to load in a test.
///
/// This includes a [MaterialApp] to provide context like [Theme.of].
/// It also provides a [Material] to support elements like [TextField] that
/// draw ink effects.
Widget wrap(Widget widget) {
  return MaterialApp(
    theme: themeFor(isDarkTheme: false),
    home: Material(child: widget),
  );
}

Widget wrapWithControllers(
  Widget widget, {
  LoggingController logging,
  MemoryController memory,
  TimelineController timeline,
  PerformanceController performance,
  BannerMessagesController bannerMessages,
}) {
  return MaterialApp(
    theme: themeFor(isDarkTheme: false),
    home: Material(
      child: Controllers.overridden(
        overrideProviders: () {
          return ProvidedControllers(
            logging: logging ?? MockLoggingController(),
            memory: memory ?? MockFlutterMemoryController(),
            timeline: timeline ?? MockTimelineController(),
            performance: performance ?? MockPerformanceController(),
            bannerMessages: bannerMessages ?? MockBannerMessagesController(),
          );
        },
        child: widget,
      ),
    ),
  );
}

Widget wrapWithBannerMessages(Widget widget) {
  return BannerMessages(
    screen: SimpleScreen(widget),
  );
}

/// Call [testWidgets], allowing the test to set specific values for app globals
/// ([MessageBus], ...).
@isTest
void testWidgetsWithContext(
  String description,
  WidgetTesterCallback callback, {
  Map<Type, dynamic> context = const {},
}) {
  testWidgets(description, (WidgetTester widgetTester) async {
    // set up the context
    final Map<Type, dynamic> oldValues = {};
    for (Type type in context.keys) {
      oldValues[type] = globals[type];
      setGlobal(type, context[type]);
    }

    try {
      await callback(widgetTester);
    } finally {
      // restore previous global values
      for (Type type in oldValues.keys) {
        setGlobal(type, oldValues[type]);
      }
    }
  });
}

/// Runs a test with the size of the app window under test to [windowSize].
@isTest
void testWidgetsWithWindowSize(
  String name,
  Size windowSize,
  WidgetTesterCallback test, {
  bool skip = false,
}) {
  testWidgets(name, (WidgetTester tester) async {
    await _setWindowSize(windowSize);
    await test(tester);
    await _resetWindowSize();
  }, skip: skip);
}

Future<void> _setWindowSize(Size windowSize) async {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  binding.window.physicalSizeTestValue = windowSize;
  binding.window.devicePixelRatioTestValue = 1.0;
}

Future<void> _resetWindowSize() async {
  await _setWindowSize(const Size(800.0, 600.0));
}

/// A test-friendly [NotificationService] that can be run in unit tests
/// instead of widget tests.
class TestNotifications implements NotificationService {
  final List<String> messages = [];

  @override
  void push(String message) {
    messages.add(message);
  }
}
