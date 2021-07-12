// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/app_size/app_size_controller.dart';
import 'package:devtools_app/src/banner_messages.dart';
import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:devtools_app/src/notifications.dart';
import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:devtools_app/src/profiler/profiler_screen_controller.dart';
import 'package:devtools_app/src/routing.dart';
import 'package:devtools_app/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';

import '../support/mocks.dart';

/// The RouterDelegate must use the same NavigatorKey when building in order
/// for widget state to be preserved.
final _testNavigatorKey = GlobalKey<NavigatorState>();

/// Wraps [widget] with the build context it needs to load in a test.
///
/// This includes a [MaterialApp] to provide context like [Theme.of], a
/// [Material] to support elements like [TextField] that draw ink effects, and a
/// [Directionality] to support [RenderFlex] widgets like [Row] and [Column].
Widget wrap(Widget widget) {
  return MaterialApp.router(
    theme: themeFor(isDarkTheme: false, ideTheme: null),
    routerDelegate: DevToolsRouterDelegate(
      (context, page, args) => MaterialPage(
        child: Material(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: widget,
          ),
        ),
      ),
      _testNavigatorKey,
    ),
    routeInformationParser: DevToolsRouteInformationParser(),
  );
}

Widget wrapWithControllers(
  Widget widget, {
  LoggingController logging,
  MemoryController memory,
  PerformanceController performance,
  ProfilerScreenController profiler,
  DebuggerController debugger,
  NetworkController network,
  BannerMessagesController bannerMessages,
  AppSizeController appSize,
}) {
  final _providers = [
    Provider<BannerMessagesController>.value(
      value: bannerMessages ?? MockBannerMessagesController(),
    ),
    if (logging != null) Provider<LoggingController>.value(value: logging),
    if (memory != null) Provider<MemoryController>.value(value: memory),
    if (performance != null)
      Provider<PerformanceController>.value(value: performance),
    if (profiler != null)
      Provider<ProfilerScreenController>.value(value: profiler),
    if (network != null) Provider<NetworkController>.value(value: network),
    if (debugger != null) Provider<DebuggerController>.value(value: debugger),
    if (appSize != null) Provider<AppSizeController>.value(value: appSize),
  ];
  return wrap(
    wrapWithNotifications(
      MultiProvider(
        providers: _providers,
        child: widget,
      ),
    ),
  );
}

Widget wrapWithNotifications(Widget child) {
  return Notifications(child: child);
}

Widget wrapWithInspectorControllers(Widget widget) {
  return wrapWithControllers(
    widget,
    debugger: DebuggerController(),
    // TODO(jacobr): add inspector controllers.
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
