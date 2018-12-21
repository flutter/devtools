// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools/inspector/diagnostics_node.dart';
import 'package:devtools/inspector/flutter_widget.dart';
import 'package:test/test.dart';

import 'package:devtools/globals.dart';
import 'package:devtools/service_manager.dart';
import 'package:devtools/vm_service_wrapper.dart';
import 'package:devtools/inspector/inspector_service.dart';

import 'matchers/matchers.dart';
import 'support/flutter_test_driver.dart';
import 'matchers/fake_flutter_matchers.dart';

/// Switch this flag to false if you are having issues with tests not running
/// atomically.
bool reuseTestEnvironment = true;

void main() {
  bool widgetCreationTracked;
  FlutterRunTestDriver _flutter;
  VmServiceWrapper service;
  InspectorService inspectorService;

  void setupEnvironment(bool trackWidgetCreation) async {
    if (trackWidgetCreation == widgetCreationTracked && reuseTestEnvironment) {
      // Setting up the environment is slow so we reuse the existing environment
      // when possible.
      return;
    }
    widgetCreationTracked = trackWidgetCreation;

    Catalog.setCatalog(
        Catalog.decode(await File('web/widgets.json').readAsString()));

    _flutter = FlutterRunTestDriver(Directory('test/fixtures/flutter_app'));

    await _flutter.run(
      withDebugger: true,
      trackWidgetCreation: trackWidgetCreation,
    );
    service = _flutter.vmService;

    setGlobal(ServiceConnectionManager, ServiceConnectionManager());

    await serviceManager.vmServiceOpened(service, Completer().future);
    inspectorService = await InspectorService.create(service);
    if (trackWidgetCreation) {
      await inspectorService.inferPubRootDirectoryIfNeeded();
    }
  }

  Future<void> tearDownEnvironment({bool force = false}) async {
    if (!force && reuseTestEnvironment) {
      // Skip actually tearing down for better test performance.
      return;
    }
    inspectorService.dispose();
    inspectorService = null;

    await service.allFuturesCompleted.future;
    await _flutter.stop();
  }

  try {
    group('inspector service tests', () {
      test('track widget creation on', () async {
        await setupEnvironment(true);
        expect(await inspectorService.isWidgetCreationTracked(), isTrue);
        await tearDownEnvironment();
      });

      test('useDaemonApi', () async {
        await setupEnvironment(true);
        expect(inspectorService.useDaemonApi, isTrue);
        // TODO(jacobr): add test where we trigger a breakpoint and verify that
        // the daemon api is now false.

        await tearDownEnvironment();
      });

      test('hasServiceMethod', () async {
        await setupEnvironment(true);
        expect(inspectorService.hasServiceMethod('someDummyName'), isFalse);
        expect(inspectorService.hasServiceMethod('getRootWidgetSummaryTree'),
            isTrue);

        await tearDownEnvironment();
      });

      test('createObjectGroup', () async {
        await setupEnvironment(true);

        var g1 = inspectorService.createObjectGroup('g1');
        var g2 = inspectorService.createObjectGroup('g2');
        expect(g1.groupName != g2.groupName, isTrue);
        expect(g1.disposed, isFalse);
        expect(g2.disposed, isFalse);
        g1.dispose();
        expect(g1.disposed, isTrue);
        expect(g2.disposed, isFalse);
        g2.dispose();
        expect(g2.disposed, isTrue);

        await tearDownEnvironment();
      });

      test('infer pub root directories', () async {
        await setupEnvironment(true);
        final group = inspectorService.createObjectGroup('test-group');
        // These tests are moot if widget creation is not tracked.
        expect(await inspectorService.isWidgetCreationTracked(), isTrue);
        await inspectorService.setPubRootDirectories([]);
        String rootDirectory =
            await inspectorService.inferPubRootDirectoryIfNeeded();
        expect(rootDirectory, endsWith('/test/fixtures/flutter_app/lib'));
        await group.dispose();

        await tearDownEnvironment();
      });

      test('widget tree', () async {
        await setupEnvironment(true);
        final group = inspectorService.createObjectGroup('test-group');
        RemoteDiagnosticsNode root =
            await group.getRoot(FlutterTreeType.widget);
        // Tree only contains widgets from local app.
        expect(
          treeToDebugString(root),
          equalsIgnoringHashCodes(
            '[root]\n'
                ' └─MyApp\n'
                '   └─MaterialApp\n'
                '     └─Scaffold\n'
                '       ├─Center\n'
                '       │ └─Text\n'
                '       └─AppBar\n'
                '         └─Text\n',
          ),
        );
        RemoteDiagnosticsNode nodeInSummaryTree =
            findNodeMatching(root, 'MaterialApp');
        expect(nodeInSummaryTree, isNotNull);
        expect(
          treeToDebugString(nodeInSummaryTree),
          equalsIgnoringHashCodes(
            'MaterialApp\n'
                ' └─Scaffold\n'
                '   ├─Center\n'
                '   │ └─Text\n'
                '   └─AppBar\n'
                '     └─Text\n',
          ),
        );
        RemoteDiagnosticsNode nodeInDetailsTree =
            await group.getDetailsSubtree(nodeInSummaryTree);
        // When flutter rolls, this string may sometimes change due to
        // implementation details.
        expect(
          treeToDebugString(nodeInDetailsTree),
          equalsIgnoringHashCodes('MaterialApp\n'
              ' │ state: _MaterialAppState#00000\n'
              ' │\n'
              ' └─ScrollConfiguration\n'
              '   │ behavior: _MaterialScrollBehavior\n'
              '   │\n'
              '   └─AnimatedTheme\n'
              '     │ duration: 200ms\n'
              '     │ state: _AnimatedThemeState#00000(ticker inactive,\n'
              '     │   ThemeDataTween(ThemeData#00000(buttonTheme:\n'
              '     │   ButtonThemeData#00000(buttonColor: Color(0xffe0e0e0),\n'
              '     │   colorScheme: ColorScheme#00000(primary: MaterialColor(primary\n'
              '     │   value: Color(0xff2196f3)), primaryVariant: Color(0xff1976d2),\n'
              '     │   secondary: Color(0xff2196f3), secondaryVariant:\n'
              '     │   Color(0xff1976d2), background: Color(0xff90caf9), error:\n'
              '     │   Color(0xffd32f2f), onSecondary: Color(0xffffffff),\n'
              '     │   onBackground: Color(0xffffffff)), materialTapTargetSize:\n'
              '     │   MaterialTapTargetSize.padded), textTheme: TextTheme#00000,\n'
              '     │   primaryTextTheme: TextTheme#00000(display4:\n'
              '     │   TextStyle(debugLabel: whiteMountainView display4, inherit:\n'
              '     │   true, color: Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), display3: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display3, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), display2: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display2, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), display1: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display1, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), headline: TextStyle(debugLabel:\n'
              '     │   whiteMountainView headline, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), title: TextStyle(debugLabel:\n'
              '     │   whiteMountainView title, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), subhead: TextStyle(debugLabel:\n'
              '     │   whiteMountainView subhead, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), body2: TextStyle(debugLabel:\n'
              '     │   whiteMountainView body2, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), body1: TextStyle(debugLabel:\n'
              '     │   whiteMountainView body1, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), caption: TextStyle(debugLabel:\n'
              '     │   whiteMountainView caption, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), button: TextStyle(debugLabel:\n'
              '     │   whiteMountainView button, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), subtitle): TextStyle(debugLabel:\n'
              '     │   whiteMountainView subtitle, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), overline: TextStyle(debugLabel:\n'
              '     │   whiteMountainView overline, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none)), accentTextTheme:\n'
              '     │   TextTheme#00000(display4: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display4, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), display3: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display3, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), display2: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display2, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), display1: TextStyle(debugLabel:\n'
              '     │   whiteMountainView display1, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), headline: TextStyle(debugLabel:\n'
              '     │   whiteMountainView headline, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), title: TextStyle(debugLabel:\n'
              '     │   whiteMountainView title, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), subhead: TextStyle(debugLabel:\n'
              '     │   whiteMountainView subhead, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), body2: TextStyle(debugLabel:\n'
              '     │   whiteMountainView body2, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), body1: TextStyle(debugLabel:\n'
              '     │   whiteMountainView body1, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), caption: TextStyle(debugLabel:\n'
              '     │   whiteMountainView caption, inherit: true, color:\n'
              '     │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), button: TextStyle(debugLabel:\n'
              '     │   whiteMountainView button, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), subtitle): TextStyle(debugLabel:\n'
              '     │   whiteMountainView subtitle, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none), overline: TextStyle(debugLabel:\n'
              '     │   whiteMountainView overline, inherit: true, color:\n'
              '     │   Color(0xffffffff), family: Roboto, decoration:\n'
              '     │   TextDecoration.none)), inputDecorationTheme:\n'
              '     │   InputDecorationTheme#00000, iconTheme:\n'
              '     │   IconThemeData#00000(color: Color(0xdd000000)),\n'
              '     │   primaryIconTheme: IconThemeData#00000(color:\n'
              '     │   Color(0xffffffff)), accentIconTheme: IconThemeData#00000(color:\n'
              '     │   Color(0xffffffff)), sliderTheme: SliderThemeData#00000,\n'
              '     │   tabBarTheme: TabBarTheme#00000, chipTheme: ChipThemeData#00000,\n'
              '     │   materialTapTargetSize: MaterialTapTargetSize.padded,\n'
              '     │   pageTransitionsTheme: PageTransitionsTheme#00000) → null))\n'
              '     │\n'
              '     └─Theme\n'
              '       │ data: ThemeData#00000(buttonTheme:\n'
              '       │   ButtonThemeData#00000(buttonColor: Color(0xffe0e0e0),\n'
              '       │   colorScheme: ColorScheme#00000(primary: MaterialColor(primary\n'
              '       │   value: Color(0xff2196f3)), primaryVariant: Color(0xff1976d2),\n'
              '       │   secondary: Color(0xff2196f3), secondaryVariant:\n'
              '       │   Color(0xff1976d2), background: Color(0xff90caf9), error:\n'
              '       │   Color(0xffd32f2f), onSecondary: Color(0xffffffff),\n'
              '       │   onBackground: Color(0xffffffff)), materialTapTargetSize:\n'
              '       │   MaterialTapTargetSize.padded), textTheme: TextTheme#00000,\n'
              '       │   primaryTextTheme: TextTheme#00000(display4:\n'
              '       │   TextStyle(debugLabel: whiteMountainView display4, inherit:\n'
              '       │   true, color: Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), display3: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display3, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), display2: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display2, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), display1: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display1, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), headline: TextStyle(debugLabel:\n'
              '       │   whiteMountainView headline, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), title: TextStyle(debugLabel:\n'
              '       │   whiteMountainView title, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), subhead: TextStyle(debugLabel:\n'
              '       │   whiteMountainView subhead, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), body2: TextStyle(debugLabel:\n'
              '       │   whiteMountainView body2, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), body1: TextStyle(debugLabel:\n'
              '       │   whiteMountainView body1, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), caption: TextStyle(debugLabel:\n'
              '       │   whiteMountainView caption, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), button: TextStyle(debugLabel:\n'
              '       │   whiteMountainView button, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), subtitle): TextStyle(debugLabel:\n'
              '       │   whiteMountainView subtitle, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), overline: TextStyle(debugLabel:\n'
              '       │   whiteMountainView overline, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none)), accentTextTheme:\n'
              '       │   TextTheme#00000(display4: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display4, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), display3: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display3, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), display2: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display2, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), display1: TextStyle(debugLabel:\n'
              '       │   whiteMountainView display1, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), headline: TextStyle(debugLabel:\n'
              '       │   whiteMountainView headline, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), title: TextStyle(debugLabel:\n'
              '       │   whiteMountainView title, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), subhead: TextStyle(debugLabel:\n'
              '       │   whiteMountainView subhead, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), body2: TextStyle(debugLabel:\n'
              '       │   whiteMountainView body2, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), body1: TextStyle(debugLabel:\n'
              '       │   whiteMountainView body1, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), caption: TextStyle(debugLabel:\n'
              '       │   whiteMountainView caption, inherit: true, color:\n'
              '       │   Color(0xb3ffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), button: TextStyle(debugLabel:\n'
              '       │   whiteMountainView button, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), subtitle): TextStyle(debugLabel:\n'
              '       │   whiteMountainView subtitle, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none), overline: TextStyle(debugLabel:\n'
              '       │   whiteMountainView overline, inherit: true, color:\n'
              '       │   Color(0xffffffff), family: Roboto, decoration:\n'
              '       │   TextDecoration.none)), inputDecorationTheme:\n'
              '       │   InputDecorationTheme#00000, iconTheme:\n'
              '       │   IconThemeData#00000(color: Color(0xdd000000)),\n'
              '       │   primaryIconTheme: IconThemeData#00000(color:\n'
              '       │   Color(0xffffffff)), accentIconTheme: IconThemeData#00000(color:\n'
              '       │   Color(0xffffffff)), sliderTheme: SliderThemeData#00000,\n'
              '       │   tabBarTheme: TabBarTheme#00000, chipTheme: ChipThemeData#00000,\n'
              '       │   materialTapTargetSize: MaterialTapTargetSize.padded,\n'
              '       │   pageTransitionsTheme: PageTransitionsTheme#00000)\n'
              '       │\n'
              '       └─_InheritedTheme\n'
              '         └─IconTheme\n'
              '           │ data: IconThemeData#00000(color: Color(0xdd000000))\n'
              '           │\n'
              '           └─CupertinoTheme\n'
              '             └─WidgetsApp-[GlobalObjectKey _MaterialAppState#00000]\n'
              '               │ state: _WidgetsAppState#00000\n'
              '               │\n'
              '               └─MediaQuery\n'
              '                 │ data: MediaQueryData(size: Size(800.0, 600.0), devicePixelRatio:\n'
              '                 │   3.0, textScaleFactor: 1.0, padding: EdgeInsets.zero,\n'
              '                 │   viewInsets: EdgeInsets.zero, alwaysUse24HourFormat: false,\n'
              '                 │   accessibleNavigation: falsedisableAnimations:\n'
              '                 │   falseinvertColors: falseboldText: false)\n'
              '                 │\n'
              '                 └─Localizations\n'
              '                   │ locale: en_US\n'
              '                   │ delegates: DefaultMaterialLocalizations.delegate(en_US),\n'
              '                   │   DefaultCupertinoLocalizations.delegate(en_US),\n'
              '                   │   DefaultWidgetsLocalizations.delegate(en_US)\n'
              '                   │ state: _LocalizationsState#00000\n'
              '                   │\n'
              '                   └─Semantics\n'
              '                     │ container: false\n'
              '                     │ properties: SemanticsProperties\n'
              '                     │ label: null\n'
              '                     │ value: null\n'
              '                     │ hint: null\n'
              '                     │ textDirection: ltr\n'
              '                     │ hintOverrides: null\n'
              '                     │ renderObject: RenderSemanticsAnnotations#00000\n'
              '                     │\n'
              '                     └─_LocalizationsScope-[GlobalKey#00000]\n'
              '                       └─Directionality\n'
              '                         │ textDirection: ltr\n'
              '                         │\n'
              '                         └─Title\n'
              '                           │ title: "Hello, World"\n'
              '                           │ color: MaterialColor(primary value: Color(0xff2196f3))\n'
              '                           │\n'
              '                           └─CheckedModeBanner\n'
              '                             │ "DEBUG"\n'
              '                             │\n'
              '                             └─Banner\n'
              '                               │ message: "DEBUG"\n'
              '                               │ textDirection: ltr\n'
              '                               │ location: topEnd\n'
              '                               │ color: Color(0xa0b71c1c)\n'
              '                               │ text inherit: true\n'
              '                               │ text color: Color(0xffffffff)\n'
              '                               │ text size: 10.2\n'
              '                               │ text weight: 900\n'
              '                               │ text height: 1.0x\n'
              '                               │\n'
              '                               └─CustomPaint\n'
              '                                 │ renderObject: RenderCustomPaint#00000\n'
              '                                 │\n'
              '                                 └─DefaultTextStyle\n'
              '                                   │ debugLabel: fallback style; consider putting your text in a\n'
              '                                   │   Material\n'
              '                                   │ inherit: true\n'
              '                                   │ color: Color(0xd0ff0000)\n'
              '                                   │ family: monospace\n'
              '                                   │ size: 48.0\n'
              '                                   │ weight: 900\n'
              '                                   │ decoration: double Color(0xffffff00) TextDecoration.underline\n'
              '                                   │ softWrap: wrapping at box width\n'
              '                                   │ overflow: clip\n'
              '                                   │\n'
              '                                   └─Navigator-[GlobalObjectKey<NavigatorState> _WidgetsAppState#00000]\n'
              '                                     │ state: NavigatorState#00000(tickers: tracking 1 ticker)\n'
              '                                     │\n'
              '                                     └─Listener\n'
              '                                       │ listeners: down, up, cancel\n'
              '                                       │ behavior: deferToChild\n'
              '                                       │ renderObject: RenderPointerListener#00000\n'
              '                                       │\n'
              '                                       └─AbsorbPointer\n'
              '                                         │ absorbing: false\n'
              '                                         │ renderObject: RenderAbsorbPointer#00000\n'
              '                                         │\n'
              '                                         └─FocusScope\n'
              '                                           │ state: _FocusScopeState#00000\n'
              '                                           │\n'
              '                                           └─Semantics\n'
              '                                             │ container: false\n'
              '                                             │ properties: SemanticsProperties\n'
              '                                             │ label: null\n'
              '                                             │ value: null\n'
              '                                             │ hint: null\n'
              '                                             │ hintOverrides: null\n'
              '                                             │ renderObject: RenderSemanticsAnnotations#00000\n'
              '                                             │\n'
              '                                             └─_FocusScopeMarker\n'
              '                                               └─Overlay-[LabeledGlobalKey<OverlayState>#00000]\n'
              '                                                 │ state: OverlayState#00000(entries: [OverlayEntry#00000(opaque:\n'
              '                                                 │   false; maintainState: false), OverlayEntry#00000(opaque: false;\n'
              '                                                 │   maintainState: true)])\n'
              '                                                 │\n'
              '                                                 └─_Theatre\n'
              '                                                   │ renderObject: _RenderTheatre#00000\n'
              '                                                   │\n'
              '                                                   └─Stack\n'
              '                                                     │ alignment: AlignmentDirectional.topStart\n'
              '                                                     │ fit: expand\n'
              '                                                     │ overflow: clip\n'
              '                                                     │ renderObject: RenderStack#00000\n'
              '                                                     │\n'
              '                                                     ├─_OverlayEntry-[LabeledGlobalKey<_OverlayEntryState>#00000]\n'
              '                                                     │ │ state: _OverlayEntryState#00000\n'
              '                                                     │ │\n'
              '                                                     │ └─IgnorePointer\n'
              '                                                     │   │ ignoring: false\n'
              '                                                     │   │ renderObject: RenderIgnorePointer#00000\n'
              '                                                     │   │\n'
              '                                                     │   └─ModalBarrier\n'
              '                                                     │     └─BlockSemantics\n'
              '                                                     │       │ blocking: true\n'
              '                                                     │       │ renderObject: RenderBlockSemantics#00000\n'
              '                                                     │       │\n'
              '                                                     │       └─ExcludeSemantics\n'
              '                                                     │         │ excluding: true\n'
              '                                                     │         │ renderObject: RenderExcludeSemantics#00000\n'
              '                                                     │         │\n'
              '                                                     │         └─GestureDetector\n'
              '                                                     │           └─RawGestureDetector\n'
              '                                                     │             │ state: RawGestureDetectorState#00000(gestures: [tap], behavior:\n'
              '                                                     │             │   opaque)\n'
              '                                                     │             │\n'
              '                                                     │             └─_GestureSemantics\n'
              '                                                     │               │ renderObject: RenderSemanticsGestureHandler#00000\n'
              '                                                     │               │\n'
              '                                                     │               └─Listener\n'
              '                                                     │                 │ listeners: down\n'
              '                                                     │                 │ behavior: opaque\n'
              '                                                     │                 │ renderObject: RenderPointerListener#00000\n'
              '                                                     │                 │\n'
              '                                                     │                 └─Semantics\n'
              '                                                     │                   │ container: false\n'
              '                                                     │                   │ properties: SemanticsProperties\n'
              '                                                     │                   │ label: null\n'
              '                                                     │                   │ value: null\n'
              '                                                     │                   │ hint: null\n'
              '                                                     │                   │ hintOverrides: null\n'
              '                                                     │                   │ renderObject: RenderSemanticsAnnotations#00000\n'
              '                                                     │                   │\n'
              '                                                     │                   └─ConstrainedBox\n'
              '                                                     │                       constraints: BoxConstraints(biggest)\n'
              '                                                     │                       renderObject: RenderConstrainedBox#00000\n'
              '                                                     │\n'
              '                                                     └─_OverlayEntry-[LabeledGlobalKey<_OverlayEntryState>#00000]\n'
              '                                                       │ state: _OverlayEntryState#00000\n'
              '                                                       │\n'
              '                                                       └─_ModalScope<dynamic>-[LabeledGlobalKey<_ModalScopeState<dynamic>>#00000]\n'
              '                                                         │ state: _ModalScopeState<dynamic>#00000\n'
              '                                                         │\n'
              '                                                         └─_ModalScopeStatus\n'
              '                                                           │ isCurrent: active\n'
              '                                                           │\n'
              '                                                           └─Offstage\n'
              '                                                             │ offstage: false\n'
              '                                                             │ renderObject: RenderOffstage#00000\n'
              '                                                             │\n'
              '                                                             └─PageStorage\n'
              '                                                               └─FocusScope\n'
              '                                                                 │ state: _FocusScopeState#00000\n'
              '                                                                 │\n'
              '                                                                 └─Semantics\n'
              '                                                                   │ container: false\n'
              '                                                                   │ properties: SemanticsProperties\n'
              '                                                                   │ label: null\n'
              '                                                                   │ value: null\n'
              '                                                                   │ hint: null\n'
              '                                                                   │ hintOverrides: null\n'
              '                                                                   │ renderObject: RenderSemanticsAnnotations#00000\n'
              '                                                                   │\n'
              '                                                                   └─_FocusScopeMarker\n'
              '                                                                     └─RepaintBoundary\n'
              '                                                                       │ renderObject: RenderRepaintBoundary#00000\n'
              '                                                                       │\n'
              '                                                                       └─AnimatedBuilder\n'
              '                                                                         │ animation: Listenable.merge([AnimationController#00000(⏭ 1.000;\n'
              '                                                                         │   paused; for MaterialPageRoute<dynamic>(/))➩ProxyAnimation,\n'
              '                                                                         │   kAlwaysDismissedAnimation➩ProxyAnimation➩ProxyAnimation])\n'
              '                                                                         │ state: _AnimatedState#00000\n'
              '                                                                         │\n'
              '                                                                         └─_FadeUpwardsPageTransition\n'
              '                                                                           └─SlideTransition\n'
              '                                                                             │ animation: AnimationController#00000(⏭ 1.000; paused; for\n'
              '                                                                             │   MaterialPageRoute<dynamic>(/))➩ProxyAnimation➩CurveTween(curve:\n'
              '                                                                             │   Cubic(0.40, 0.00, 0.20, 1.00))➩Tween<Offset>(Offset(0.0, 0.3) →\n'
              '                                                                             │   Offset(0.0, 0.0))➩Offset(0.0, 0.0)\n'
              '                                                                             │ state: _AnimatedState#00000\n'
              '                                                                             │\n'
              '                                                                             └─FractionalTranslation\n'
              '                                                                               │ renderObject: RenderFractionalTranslation#00000\n'
              '                                                                               │\n'
              '                                                                               └─FadeTransition\n'
              '                                                                                 │ opacity: AnimationController#00000(⏭ 1.000; paused; for\n'
              '                                                                                 │   MaterialPageRoute<dynamic>(/))➩ProxyAnimation➩CurveTween(curve:\n'
              '                                                                                 │   Cubic(0.42, 0.00, 1.00, 1.00))➩1.0\n'
              '                                                                                 │ renderObject: RenderAnimatedOpacity#00000\n'
              '                                                                                 │\n'
              '                                                                                 └─IgnorePointer\n'
              '                                                                                   │ ignoring: false\n'
              '                                                                                   │ renderObject: RenderIgnorePointer#00000\n'
              '                                                                                   │\n'
              '                                                                                   └─RepaintBoundary-[GlobalKey#00000]\n'
              '                                                                                     │ renderObject: RenderRepaintBoundary#00000\n'
              '                                                                                     │\n'
              '                                                                                     └─Builder\n'
              '                                                                                       └─Semantics\n'
              '                                                                                         │ container: false\n'
              '                                                                                         │ properties: SemanticsProperties\n'
              '                                                                                         │ label: null\n'
              '                                                                                         │ value: null\n'
              '                                                                                         │ hint: null\n'
              '                                                                                         │ hintOverrides: null\n'
              '                                                                                         │ renderObject: RenderSemanticsAnnotations#00000\n'
              '                                                                                         │\n'
              '                                                                                         └─Scaffold\n'
              '                                                                                             state: ScaffoldState#00000(tickers: tracking 1 ticker)\n'),
        );

        nodeInSummaryTree = findNodeMatching(root, 'Text');
        expect(nodeInSummaryTree, isNotNull);
        expect(
          treeToDebugString(nodeInSummaryTree),
          equalsIgnoringHashCodes(
            'Text\n',
          ),
        );

        nodeInDetailsTree = await group.getDetailsSubtree(nodeInSummaryTree);
        expect(
          treeToDebugString(nodeInDetailsTree),
          equalsIgnoringHashCodes(
            'Text\n'
                ' │ data: "Hello, World!"\n'
                ' │ textAlign: null\n'
                ' │ textDirection: null\n'
                ' │ locale: null\n'
                ' │ softWrap: null\n'
                ' │ overflow: null\n'
                ' │ textScaleFactor: null\n'
                ' │ maxLines: null\n'
                ' │\n'
                ' └─RichText\n'
                '     softWrap: wrapping at box width\n'
                '     maxLines: unlimited\n'
                '     text: "Hello, World!"\n'
                '     renderObject: RenderParagraph#00000 relayoutBoundary=up2\n',
          ),
        );
        expect(nodeInDetailsTree.valueRef, equals(nodeInSummaryTree.valueRef));

        await group.setSelectionInspector(nodeInDetailsTree.valueRef, true);
        var selection =
            await group.getSelection(null, FlutterTreeType.widget, false);
        expect(selection, isNotNull);
        expect(selection.valueRef, equals(nodeInDetailsTree.valueRef));
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes('Text\n'
              ' └─RichText\n'),
        );

        // Get selection in the render tree.
        selection =
            await group.getSelection(null, FlutterTreeType.renderObject, false);
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes('RenderParagraph#00000 relayoutBoundary=up2\n'
              ' └─text: TextSpan\n'),
        );

        await group.dispose();

        await tearDownEnvironment();
      });

      test('render tree', () async {
        await setupEnvironment(false);

        final group = inspectorService.createObjectGroup('test-group');
        RemoteDiagnosticsNode root =
            await group.getRoot(FlutterTreeType.renderObject);
        // Tree only contains widgets from local app.
        expect(
          treeToDebugString(root),
          equalsIgnoringHashCodes(
            'RenderView#00000\n'
                ' └─child: RenderSemanticsAnnotations#00000\n',
          ),
        );
        var child = findNodeMatching(root, 'RenderSemanticsAnnotations');
        expect(child, isNotNull);
        var childDetailsSubtree = await group.getDetailsSubtree(child);
        expect(
          treeToDebugString(childDetailsSubtree),
          equalsIgnoringHashCodes(
            'child: RenderSemanticsAnnotations#00000\n'
                ' │ parentData: <none>\n'
                ' │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
                ' │ size: Size(800.0, 600.0)\n'
                ' │\n'
                ' └─child: RenderCustomPaint#00000\n'
                '   │ parentData: <none> (can use size)\n'
                '   │ constraints: BoxConstraints(w=800.0, h=600.0)\n'
                '   │ size: Size(800.0, 600.0)\n'
                '   │\n'
                '   └─child: RenderPointerListener#00000\n'
                '       parentData: <none> (can use size)\n'
                '       constraints: BoxConstraints(w=800.0, h=600.0)\n'
                '       size: Size(800.0, 600.0)\n'
                '       behavior: deferToChild\n'
                '       listeners: down, up, cancel\n',
          ),
        );

        await group.setSelectionInspector(child.valueRef, true);
        var selection =
            await group.getSelection(null, FlutterTreeType.renderObject, false);
        expect(selection, isNotNull);
        expect(selection.valueRef, equals(child.valueRef));
        expect(
          treeToDebugString(selection),
          equalsIgnoringHashCodes(
            'RenderSemanticsAnnotations#00000\n'
                ' └─child: RenderCustomPaint#00000\n',
          ),
        );

        await tearDownEnvironment();
      });

      // Run this test last as it will take a long time due to setting up the test
      // environment from scratch.
      test('track widget creation off', () async {
        await setupEnvironment(false);

        expect(await inspectorService.isWidgetCreationTracked(), isFalse);

        await tearDownEnvironment(force: true);
      });

      // TODO(jacobr): add tests verifying that we can stop the running device
      // without the InspectorService spewing a bunch of errors.
    }, tags: 'useFlutterSdk');
  } catch (e, s) {
    print(s);
  }
}
