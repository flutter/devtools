// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/banner_messages.dart';
import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/notifications.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/theme.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';

import '../support/mocks.dart';

/// Wraps [widget] with the build context it needs to load in a test.
///
/// This includes a [MaterialApp] to provide context like [Theme.of], a
/// [Material] to support elements like [TextField] that draw ink effects, and a
/// [Directionality] to support [RenderFlex] widgets like [Row] and [Column].
Widget wrap(Widget widget) {
  return MaterialApp(
    theme: themeFor(isDarkTheme: false, ideTheme: null),
    home: Material(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ),
    ),
  );
}

Widget wrapWithControllers(
  Widget widget, {
  LoggingController logging,
  MemoryController memory,
  TimelineController timeline,
  PerformanceController performance,
  DebuggerController debugger,
  NetworkController network,
  BannerMessagesController bannerMessages,
  CodeSizeController codeSize,
}) {
  final _providers = [
    Provider<BannerMessagesController>.value(
      value: bannerMessages ?? MockBannerMessagesController(),
    ),
    if (logging != null) Provider<LoggingController>.value(value: logging),
    if (memory != null) Provider<MemoryController>.value(value: memory),
    if (timeline != null) Provider<TimelineController>.value(value: timeline),
    if (performance != null)
      Provider<PerformanceController>.value(value: performance),
    if (network != null) Provider<NetworkController>.value(value: network),
    if (debugger != null) Provider<DebuggerController>.value(value: debugger),
    if (codeSize != null) Provider<CodeSizeController>.value(value: codeSize),
  ];
  return wrap(
    MultiProvider(
      providers: _providers,
      child: widget,
    ),
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
