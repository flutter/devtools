// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member, fine for test only package.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/query_parameters.dart';
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
Widget wrap(Widget widget, {DevToolsQueryParams? queryParams}) {
  setGlobal(GlobalKey<NavigatorState>, _testNavigatorKey);
  return MaterialApp.router(
    theme: themeFor(
      isDarkTheme: false,
      ideTheme: IdeTheme(),
      theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
    ),
    routerDelegate: DevToolsRouterDelegate.test(
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
    routeInformationParser: DevToolsRouteInformationParser.test(
      DevToolsQueryParams({
        'uri': 'http://test/uri',
      }).withUpdates(queryParams?.params),
    ),
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
      theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
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
  InspectorScreenController? inspector,
  LoggingController? logging,
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
  DevToolsQueryParams? queryParams,
}) {
  // The [ScreenControllers] class uses the [OfflineDataController] class to
  // determine which type of controller should be returned from
  // [ScreenController.lookup]. Set the global here if it is not already set.
  if (globals[OfflineDataController] == null) {
    setGlobal(OfflineDataController, OfflineDataController());
  }
  final offline = offlineDataController.showingOfflineData.value;
  setGlobal(ScreenControllers, ScreenControllers());
  if (inspector != null) {
    screenControllers.register<InspectorScreenController>(
      () => inspector,
      offline: offline,
    );
  }
  if (logging != null) {
    screenControllers.register<LoggingController>(
      () => logging,
      offline: offline,
    );
  }
  if (memory != null) {
    screenControllers.register<MemoryController>(
      () => memory,
      offline: offline,
    );
  }
  if (performance != null) {
    screenControllers.register<PerformanceController>(
      () => performance,
      offline: offline,
    );
  }
  if (profiler != null) {
    screenControllers.register<ProfilerScreenController>(
      () => profiler,
      offline: offline,
    );
  }
  if (network != null) {
    screenControllers.register<NetworkController>(
      () => network,
      offline: offline,
    );
  }
  if (debugger != null) {
    screenControllers.register<DebuggerController>(
      () => debugger,
      offline: offline,
    );
  }
  if (deepLink != null) {
    screenControllers.register<DeepLinksController>(
      () => deepLink,
      offline: offline,
    );
  }
  if (appSize != null) {
    screenControllers.register<AppSizeController>(
      () => appSize,
      offline: offline,
    );
  }
  if (vmDeveloperTools != null) {
    screenControllers.register<VMDeveloperToolsController>(
      () => vmDeveloperTools,
      offline: offline,
    );
  }

  var child = wrapWithNotifications(widget);
  final providers = [
    if (analytics != null)
      Provider<AnalyticsController>.value(value: analytics),
    if (releaseNotes != null)
      Provider<ReleaseNotesController>.value(value: releaseNotes),
  ];
  if (providers.isNotEmpty) {
    child = MultiProvider(providers: providers, child: child);
  }
  return includeRouter
      ? wrap(child, queryParams: queryParams)
      : wrapSimple(child);
}

Widget wrapWithNotifications(Widget child) {
  return NotificationsView(child: child);
}

Widget wrapWithInspectorControllers(Widget widget) {
  return wrapWithControllers(
    widget,
    debugger: DebuggerController(),
    inspector: InspectorScreenController(),
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
    final oldValues = <Type, Object?>{};
    for (final type in context.keys) {
      oldValues[type] = globals[type];
      setGlobal(type, context[type]);
    }

    try {
      await callback(widgetTester);
    } finally {
      // restore previous global values
      for (final type in oldValues.keys) {
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
  testWidgets(name, (WidgetTester tester) async {
    await _setWindowSize(tester, windowSize);
    await test(tester);
    await _resetWindowSize(tester);
  }, skip: skip);
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
