// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';

/// The RouterDelegate must use the same NavigatorKey when building in order
/// for widget state to be preserved.
final _testNavigatorKey = GlobalKey<NavigatorState>();

/// Wraps [widget] with the build context it needs to load in a test as well as
/// the [DevToolsRouterDelegate].
///
/// This includes a [MaterialApp] to provide context like [Theme.of], a
/// [Material] to support elements like [TextField] that draw ink effects, and a
/// [Directionality] to support [RenderFlex] widgets like [Row] and [Column].
Widget wrap(Widget widget) {
  return MaterialApp.router(
    theme: themeFor(
      isDarkTheme: false,
      ideTheme: IdeTheme(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
      ),
    ),
    routerDelegate: DevToolsRouterDelegate(
      (context, page, args, state) => MaterialPage(
        child: Material(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Provider<HoverCardController>.value(
              value: HoverCardController(),
              child: widget,
            ),
          ),
        ),
      ),
      _testNavigatorKey,
    ),
    routeInformationParser:
        // ignore: invalid_use_of_visible_for_testing_member, false positive.
        DevToolsRouteInformationParser.test('http://test/uri'),
  );
}

/// Wraps [widget] with the build context it needs to load in a test.
///
/// This includes a [MaterialApp] to provide context like [Theme.of], a
/// [Material] to support elements like [TextField] that draw ink effects, and a
/// [Directionality] to support [RenderFlex] widgets like [Row] and [Column].
Widget wrapSimple(Widget widget) {
  return MaterialApp(
    theme: themeFor(
      isDarkTheme: false,
      ideTheme: IdeTheme(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
      ),
    ),
    home: Material(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Provider<HoverCardController>.value(
          value: HoverCardController(),
          child: widget,
        ),
      ),
    ),
  );
}

Widget wrapWithControllers(
  Widget widget, {
  InspectorController? inspector,
  LoggingController? logging,
  LoggingControllerV2? loggingV2,
  MemoryController? memory,
  PerformanceController? performance,
  ProfilerScreenController? profiler,
  DebuggerController? debugger,
  DeepLinksController? deepLink,
  NetworkController? network,
  AppSizeController? appSize,
  AnalyticsController? analytics,
  ReleaseNotesController? releaseNotes,
  VMDeveloperToolsController? vmDeveloperTools,
  bool includeRouter = true,
}) {
  final providers = [
    if (inspector != null)
      Provider<InspectorController>.value(value: inspector),
    if (logging != null) Provider<LoggingController>.value(value: logging),
    if (loggingV2 != null)
      Provider<LoggingControllerV2>.value(value: loggingV2),
    if (memory != null) Provider<MemoryController>.value(value: memory),
    if (performance != null)
      Provider<PerformanceController>.value(value: performance),
    if (profiler != null)
      Provider<ProfilerScreenController>.value(value: profiler),
    if (network != null) Provider<NetworkController>.value(value: network),
    if (debugger != null) Provider<DebuggerController>.value(value: debugger),
    if (deepLink != null) Provider<DeepLinksController>.value(value: deepLink),
    if (appSize != null) Provider<AppSizeController>.value(value: appSize),
    if (analytics != null)
      Provider<AnalyticsController>.value(value: analytics),
    if (releaseNotes != null)
      Provider<ReleaseNotesController>.value(value: releaseNotes),
    if (vmDeveloperTools != null)
      Provider<VMDeveloperToolsController>.value(value: vmDeveloperTools),
  ];
  final child = wrapWithNotifications(
    MultiProvider(
      providers: providers,
      child: widget,
    ),
  );
  return includeRouter ? wrap(child) : wrapSimple(child);
}

Widget wrapWithNotifications(Widget child) {
  return NotificationsView(child: child);
}

Widget wrapWithInspectorControllers(Widget widget) {
  final inspectorController = InspectorController(
    inspectorTree: InspectorTreeController(),
    detailsTree: InspectorTreeController(),
    treeType: FlutterTreeType.widget,
  );
  return wrapWithControllers(
    widget,
    debugger: DebuggerController(),
    inspector: inspectorController,
  );
}

/// Call [testWidgets], allowing the test to set specific values for app globals
/// ([MessageBus], ...).
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
        final oldGlobal = oldValues[type];
        if (oldGlobal != null) {
          setGlobal(type, oldGlobal);
        } else {
          globals.remove(type);
        }
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
  testWidgets(
    name,
    (WidgetTester tester) async {
      await _setWindowSize(tester, windowSize);
      await test(tester);
      await _resetWindowSize(tester);
    },
    skip: skip,
  );
}

Future<void> _setWindowSize(WidgetTester tester, Size windowSize) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  tester.view.physicalSize = windowSize;
  tester.view.devicePixelRatio = 1.0;
}

Future<void> _resetWindowSize(WidgetTester tester) async {
  await _setWindowSize(tester, const Size(800.0, 600.0));
}
