// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'generated_mocks_factories.dart';

class FakeIsolateManager extends Fake implements IsolateManager {
  @override
  ValueListenable<IsolateRef?> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate = ValueNotifier(
    IsolateRef.parse({
      'id': 'fake_isolate_id',
      'name': 'selected-isolate',
    }),
  );

  @override
  ValueListenable<IsolateRef?> get mainIsolate => _mainIsolate;
  final _mainIsolate =
      ValueNotifier(IsolateRef.parse({'id': 'fake_main_isolate_id'}));

  @override
  ValueNotifier<List<IsolateRef>> get isolates {
    final value = _selectedIsolate.value;
    _isolates ??= ValueNotifier([if (value != null) value]);
    return _isolates!;
  }

  @override
  IsolateState? get mainIsolateDebuggerState {
    return MockIsolateState();
  }

  ValueNotifier<List<IsolateRef>>? _isolates;

  @override
  IsolateState isolateDebuggerState(IsolateRef? isolate) {
    final state = MockIsolateState();
    final mockIsolate = MockIsolate();
    when(mockIsolate.libraries).thenReturn([]);
    when(state.isolateNow).thenReturn(mockIsolate);
    return state;
  }
}

class FakeInspectorService extends Fake implements InspectorService {
  final pubRootDirectories = <String>{};
  @override
  ObjectGroup createObjectGroup(String debugName) {
    return ObjectGroup(debugName, this);
  }

  @override
  Future<bool> isWidgetTreeReady() async {
    return false;
  }

  @override
  Future<List<String>> inferPubRootDirectoryIfNeeded() async {
    return ['/some/directory'];
  }

  @override
  Future<List<String>?> getPubRootDirectories() {
    return Future.value(pubRootDirectories.toList());
  }

  @override
  Future<void> addPubRootDirectories(List<String> rootDirectories) {
    pubRootDirectories.addAll(rootDirectories);
    return Future<void>.value();
  }

  @override
  Future<void> removePubRootDirectories(List<String> rootDirectories) {
    pubRootDirectories.removeAll(rootDirectories);
    return Future<void>.value();
  }

  @override
  bool get useDaemonApi => true;

  @override
  final Set<InspectorServiceClient> clients = {};

  @override
  void addClient(InspectorServiceClient client) {
    clients.add(client);
  }

  @override
  void removeClient(InspectorServiceClient client) {
    clients.remove(client);
  }
}

class MockInspectorTreeController extends Mock
    implements InspectorTreeController {}

class TestInspectorController extends Fake implements InspectorController {
  InspectorService service = FakeInspectorService();

  @override
  ValueListenable<InspectorTreeNode?> get selectedNode => _selectedNode;
  final ValueNotifier<InspectorTreeNode?> _selectedNode = ValueNotifier(null);

  @override
  void setSelectedNode(InspectorTreeNode? newSelection) {
    _selectedNode.value = newSelection;
  }

  @override
  InspectorService get inspectorService => service;
}

class FakeVM extends Fake implements VM {
  FakeVM();

  @override
  Map<String, dynamic>? json = {
    '_FAKE_VM': true,
    '_currentRSS': 0,
  };
}

class MockIsolateState extends Mock implements IsolateState {
  @override
  ValueListenable<bool?> get isPaused => ValueNotifier<bool>(false);
}

class MockIsolate extends Mock implements Isolate {}

class MockObj extends Mock implements Obj {}

class MockCpuSamples extends Mock implements CpuSamples {}

// TODO(kenz): make it easier to mock a connected app by adding a constructor
// that will override the public getters on the class (e.g. isFlutterAppNow,
// isProfileBuildNow, etc.). Do this after devtools_app is migrated to null
// safety so that we can use null-safety here.
// TODO(polinach): delete this class.
// See https://github.com/flutter/devtools/issues/4029.
class MockConnectedAppLegacy extends Mock implements ConnectedApp {}

class FakeConnectedApp extends Mock implements ConnectedApp {}

class MockBannerMessagesController extends Mock
    implements BannerMessagesController {}

class MockLoggingController extends Mock
    with SearchControllerMixin<LogData>, FilterControllerMixin<LogData>
    implements LoggingController {
  @override
  ValueListenable<LogData?> get selectedLog => _selectedLog;

  final _selectedLog = ValueNotifier<LogData?>(null);

  @override
  void selectLog(LogData data) {
    _selectedLog.value = data;
  }

  @override
  List<LogData> data = <LogData>[];
}

class MockMemoryController extends Mock implements MemoryController {}

class MockFlutterMemoryController extends Mock implements MemoryController {}

class MockProfilerScreenController extends Mock
    implements ProfilerScreenController {}

class MockStorage extends Mock implements Storage {}

class TestCodeViewController extends CodeViewController {
  @override
  ProgramExplorerController get programExplorerController =>
      _explorerController;
  final _explorerController = createMockProgramExplorerControllerWithDefaults();
}

// TODO(polinach): delete this class.
// See https://github.com/flutter/devtools/issues/4029.
class MockDebuggerControllerLegacy extends Mock implements DebuggerController {
  MockDebuggerControllerLegacy();

  factory MockDebuggerControllerLegacy.withDefaults() {
    final debuggerController = MockDebuggerControllerLegacy();
    when(debuggerController.isPaused).thenReturn(ValueNotifier(false));
    when(debuggerController.resuming).thenReturn(ValueNotifier(false));
    when(debuggerController.isSystemIsolate).thenReturn(false);
    when(debuggerController.selectedBreakpoint).thenReturn(ValueNotifier(null));
    when(debuggerController.stackFramesWithLocation)
        .thenReturn(ValueNotifier([]));
    when(debuggerController.selectedStackFrame).thenReturn(ValueNotifier(null));
    when(debuggerController.hasTruncatedFrames)
        .thenReturn(ValueNotifier(false));
    when(debuggerController.exceptionPauseMode)
        .thenReturn(ValueNotifier('Unhandled'));
    when(debuggerController.variables).thenReturn(ValueNotifier([]));
    return debuggerController;
  }
}

class MockScriptManagerLegacy extends Mock implements ScriptManager {}

// TODO(polinach): delete this class.
// See https://github.com/flutter/devtools/issues/4029.
class MockProgramExplorerControllerLegacy extends Mock
    implements ProgramExplorerController {
  MockProgramExplorerControllerLegacy();

  factory MockProgramExplorerControllerLegacy.withDefaults() {
    final controller = MockProgramExplorerControllerLegacy();
    when(controller.initialized).thenReturn(ValueNotifier(true));
    when(controller.rootObjectNodes).thenReturn(ValueNotifier([]));
    when(controller.outlineNodes).thenReturn(ValueNotifier([]));
    when(controller.outlineSelection).thenReturn(ValueNotifier(null));
    when(controller.isLoadingOutline).thenReturn(ValueNotifier(false));

    return controller;
  }
}

class MockVM extends Mock implements VM {}

Future<void> ensureInspectorDependencies() async {
  assert(
    !kIsWeb,
    'Attempted to resolve a package path from web code.\n'
    'Package path resolution uses dart:io, which is not available in web.'
    '\n'
    "To fix this, mark the failing test as @TestOn('vm')",
  );
}

void mockWebVm(VM vm) {
  when(vm.targetCPU).thenReturn('Web');
  when(vm.architectureBits).thenReturn(-1);
  when(vm.operatingSystem).thenReturn('macos');
}

void mockConnectedApp(
  ConnectedApp connectedApp, {
  required bool isFlutterApp,
  required isProfileBuild,
  required isWebApp,
}) {
  assert(!(!isFlutterApp && isProfileBuild));

  // Dart VM.
  when(connectedApp.isRunningOnDartVM).thenReturn(!isWebApp);

  // Flutter app.
  when(connectedApp.isFlutterAppNow).thenReturn(isFlutterApp);
  when(connectedApp.isFlutterApp).thenAnswer((_) => Future.value(isFlutterApp));
  when(connectedApp.isFlutterNativeAppNow)
      .thenReturn(isFlutterApp && !isWebApp);
  if (isFlutterApp) {
    when(connectedApp.flutterVersionNow).thenReturn(
      FlutterVersion.parse({
        'type': 'Success',
        'frameworkVersion': '2.10.0',
        'channel': 'unknown',
        'repositoryUrl': 'unknown source',
        'frameworkRevision': '74432fa91c8ffbc555ffc2701309e8729380a012',
        'frameworkCommitDate': '2020-05-14 13:05:34 -0700',
        'engineRevision': 'ae2222f47e788070c09020311b573542b9706a78',
        'dartSdkVersion': '2.9.0 (build 2.9.0-8.0.dev d6fed1f624)',
        'frameworkRevisionShort': '74432fa91c',
        'engineRevisionShort': 'ae2222f47e',
      }),
    );
  } else {
    when(connectedApp.flutterVersionNow).thenReturn(null);
  }

  // Flutter web app.
  when(connectedApp.isFlutterWebAppNow).thenReturn(isFlutterApp && isWebApp);

  // Web app.
  when(connectedApp.isDartWebApp).thenAnswer((_) => Future.value(isWebApp));
  when(connectedApp.isDartWebAppNow).thenReturn(isWebApp);

  // CLI app.
  final isCliApp = !isFlutterApp && !isWebApp;
  when(connectedApp.isDartCliApp).thenAnswer((_) => Future.value(isCliApp));
  when(connectedApp.isDartCliAppNow).thenReturn(isCliApp);

  // Run mode.
  when(connectedApp.isProfileBuild)
      .thenAnswer((_) => Future.value(isProfileBuild));
  when(connectedApp.isProfileBuildNow).thenReturn(isProfileBuild);
  when(connectedApp.isDebugFlutterAppNow)
      .thenReturn(isFlutterApp && !isProfileBuild);

  // Initialized.
  when(connectedApp.connectedAppInitialized).thenReturn(true);
  when(connectedApp.initialized).thenReturn(Completer()..complete(true));
}

void mockFlutterVersion(
  ConnectedApp connectedApp,
  SemanticVersion version,
) {
  when(connectedApp.flutterVersionNow).thenReturn(
    FlutterVersion.parse({
      'frameworkVersion': '$version',
    }),
  );
  when(connectedApp.connectedAppInitialized).thenReturn(true);
}

// ignore: prefer_single_quotes
final Grammar mockGrammar = Grammar.fromJson(
  jsonDecode(
    '''
{
  "name": "Dart",
  "fileTypes": [
    "dart"
  ],
  "scopeName": "source.dart",
  "patterns": [],
  "repository": {}
}
''',
  ),
);

final Script? mockScript = Script.parse(
  jsonDecode(
    """
{
  "type": "Script",
  "class": {
    "type": "@Class",
    "fixedId": true,
    "id": "classes/11",
    "name": "Script",
    "library": {
      "type": "@Instance",
      "_vmType": "null",
      "class": {
        "type": "@Class",
        "fixedId": true,
        "id": "classes/148",
        "name": "Null",
        "location": {
          "type": "SourceLocation",
          "script": {
            "type": "@Script",
            "fixedId": true,
            "id": "libraries/@0150898/scripts/dart%3Acore%2Fnull.dart/0",
            "uri": "dart:core/null.dart",
            "_kind": "kernel"
          },
          "tokenPos": 925,
          "endTokenPos": 1165
        },
        "library": {
          "type": "@Library",
          "fixedId": true,
          "id": "libraries/@0150898",
          "name": "dart.core",
          "uri": "dart:core"
        }
      },
      "kind": "Null",
      "fixedId": true,
      "id": "objects/null",
      "valueAsString": "null"
    }
  },
  "size": 80,
  "fixedId": true,
  "id": "libraries/@783137924/scripts/package%3Agallery%2Fmain.dart/17b557e5bc3",
  "uri": "package:gallery/main.dart",
  "_kind": "kernel",
  "_loadTime": 1629226949571,
  "library": {
    "type": "@Library",
    "fixedId": true,
    "id": "libraries/@783137924",
    "name": "",
    "uri": "package:gallery/main.dart"
  },
  "lineOffset": 0,
  "columnOffset": 0,
  "source": "// Copyright 2019 The Flutter team. All rights reserved.\\n// Use of this source code is governed by a BSD-style license that can be\\n// found in the LICENSE file.\\n\\nimport 'package:flutter/foundation.dart';\\nimport 'package:flutter/material.dart';\\nimport 'package:flutter/scheduler.dart' show timeDilation;\\nimport 'package:flutter_gen/gen_l10n/gallery_localizations.dart';\\nimport 'package:flutter_localized_locales/flutter_localized_locales.dart';\\nimport 'package:gallery/constants.dart';\\nimport 'package:gallery/data/gallery_options.dart';\\nimport 'package:gallery/pages/backdrop.dart';\\nimport 'package:gallery/pages/splash.dart';\\nimport 'package:gallery/routes.dart';\\nimport 'package:gallery/themes/gallery_theme_data.dart';\\nimport 'package:google_fonts/google_fonts.dart';\\n\\nexport 'package:gallery/data/demos.dart' show pumpDeferredLibraries;\\n\\nvoid main() {\\n  GoogleFonts.config.allowRuntimeFetching = false;\\n  runApp(const GalleryApp());\\n}\\n\\nclass GalleryApp extends StatelessWidget {\\n  const GalleryApp({\\n    Key key,\\n    this.initialRoute,\\n    this.isTestMode = false,\\n  }) : super(key: key);\\n\\n  final bool isTestMode;\\n  final String initialRoute;\\n\\n  @override\\n  Widget build(BuildContext context) {\\n    return ModelBinding(\\n      initialModel: GalleryOptions(\\n        themeMode: ThemeMode.system,\\n        textScaleFactor: systemTextScaleFactorOption,\\n        customTextDirection: CustomTextDirection.localeBased,\\n        locale: null,\\n        timeDilation: timeDilation,\\n        platform: defaultTargetPlatform,\\n        isTestMode: isTestMode,\\n      ),\\n      child: Builder(\\n        builder: (context) {\\n          return MaterialApp(\\n            // By default on desktop, scrollbars are applied by the\\n            // ScrollBehavior. This overrides that. All vertical scrollables in\\n            // the gallery need to be audited before enabling this feature,\\n            // see https://github.com/flutter/gallery/issues/523\\n            scrollBehavior:\\n                const MaterialScrollBehavior().copyWith(scrollbars: false),\\n            restorationScopeId: 'rootGallery',\\n            title: 'Flutter Gallery',\\n            debugShowCheckedModeBanner: false,\\n            themeMode: GalleryOptions.of(context).themeMode,\\n            theme: GalleryThemeData.lightThemeData.copyWith(\\n              platform: GalleryOptions.of(context).platform,\\n            ),\\n            darkTheme: GalleryThemeData.darkThemeData.copyWith(\\n              platform: GalleryOptions.of(context).platform,\\n            ),\\n            localizationsDelegates: const [\\n              ...GalleryLocalizations.localizationsDelegates,\\n              LocaleNamesLocalizationsDelegate()\\n            ],\\n            initialRoute: initialRoute,\\n            supportedLocales: GalleryLocalizations.supportedLocales,\\n            locale: GalleryOptions.of(context).locale,\\n            localeResolutionCallback: (locale, supportedLocales) {\\n              deviceLocale = locale;\\n              return locale;\\n            },\\n            onGenerateRoute: RouteConfiguration.onGenerateRoute,\\n          );\\n        },\\n      ),\\n    );\\n  }\\n}\\n\\nclass RootPage extends StatelessWidget {\\n  const RootPage({\\n    Key key,\\n  }) : super(key: key);\\n\\n  @override\\n  Widget build(BuildContext context) {\\n    return const ApplyTextOptions(\\n      child: SplashPage(\\n        child: Backdrop(),\\n      ),\\n    );\\n  }\\n}\\n",
  "tokenPosTable": [
    [
      20,
      842,
      1,
      847,
      6,
      851,
      10,
      854,
      13
    ],
    [
      21,
      870,
      15,
      877,
      22
    ],
    [
      22,
      909,
      3,
      922,
      16
    ],
    [
      23,
      937,
      1
    ],
    [
      25,
      940,
      1
    ],
    [
      26,
      985,
      3,
      991,
      9,
      1001,
      19
    ],
    [
      27,
      1012,
      9
    ],
    [
      28,
      1026,
      10
    ],
    [
      29,
      1049,
      10,
      1062,
      23
    ],
    [
      30,
      1076,
      8,
      1087,
      19,
      1091,
      23
    ],
    [
      32,
      1107,
      14,
      1117,
      24
    ],
    [
      33,
      1134,
      16,
      1146,
      28
    ],
    [
      35,
      1151,
      3,
      1152,
      4
    ],
    [
      36,
      1170,
      10,
      1175,
      15,
      1189,
      29,
      1198,
      38
    ],
    [
      37,
      1204,
      5,
      1211,
      12
    ],
    [
      38,
      1245,
      21
    ],
    [
      39,
      1290,
      30
    ],
    [
      40,
      1323,
      26
    ],
    [
      41,
      1401,
      50
    ],
    [
      43,
      1458,
      23
    ],
    [
      44,
      1490,
      19
    ],
    [
      45,
      1533,
      21
    ],
    [
      47,
      1567,
      14
    ],
    [
      48,
      1593,
      18,
      1594,
      19,
      1603,
      28
    ],
    [
      49,
      1615,
      11,
      1622,
      18
    ],
    [
      55,
      1974,
      23,
      1999,
      48
    ],
    [
      59,
      2198,
      39,
      2201,
      42,
      2210,
      51
    ],
    [
      60,
      2257,
      37,
      2272,
      52
    ],
    [
      61,
      2321,
      40,
      2324,
      43,
      2333,
      52
    ],
    [
      63,
      2398,
      41,
      2412,
      55
    ],
    [
      64,
      2461,
      40,
      2464,
      43,
      2473,
      52
    ],
    [
      66,
      2534,
      37
    ],
    [
      70,
      2694,
      27
    ],
    [
      71,
      2759,
      52
    ],
    [
      72,
      2812,
      36,
      2815,
      39,
      2824,
      48
    ],
    [
      73,
      2870,
      39,
      2871,
      40,
      2879,
      48,
      2897,
      66
    ],
    [
      74,
      2913,
      15,
      2928,
      30
    ],
    [
      75,
      2950,
      15,
      2957,
      22
    ],
    [
      76,
      2977,
      13,
      2978,
      14
    ],
    [
      77,
      3028,
      49
    ],
    [
      79,
      3066,
      9,
      3067,
      10
    ],
    [
      82,
      3087,
      3
    ],
    [
      83,
      3089,
      1
    ],
    [
      85,
      3092,
      1
    ],
    [
      86,
      3135,
      3,
      3141,
      9,
      3149,
      17
    ],
    [
      87,
      3160,
      9
    ],
    [
      88,
      3172,
      8,
      3183,
      19,
      3187,
      23
    ],
    [
      90,
      3192,
      3,
      3193,
      4
    ],
    [
      91,
      3211,
      10,
      3216,
      15,
      3230,
      29,
      3239,
      38
    ],
    [
      92,
      3245,
      5,
      3258,
      18
    ],
    [
      97,
      3346,
      3
    ],
    [
      98,
      3348,
      1
    ]
  ]
}
""",
  ),
);

final mockScriptRef = ScriptRef(
  uri:
      'libraries/@783137924/scripts/package%3Agallery%2Fmain.dart/17b557e5bc3"',
  id: 'test-script-long-lines',
);

final mockSyntaxHighlighter = SyntaxHighlighter.withGrammar(
  grammar: mockGrammar,
  source: mockScript!.source,
);

final mockParsedScript = ParsedScript(
  script: mockScript!,
  highlighter: mockSyntaxHighlighter,
  executableLines: <int>{},
);

final mockScriptRefs = [
  ScriptRef(uri: 'zoo:animals/cats/meow.dart', id: 'fake/id/1'),
  ScriptRef(uri: 'zoo:animals/cats/purr.dart', id: 'fake/id/2'),
  ScriptRef(uri: 'zoo:animals/dogs/bark.dart', id: 'fake/id/3'),
  ScriptRef(uri: 'zoo:animals/dogs/growl.dart', id: 'fake/id/4'),
  ScriptRef(uri: 'zoo:animals/insects/caterpillar.dart', id: 'fake/id/5'),
  ScriptRef(uri: 'zoo:animals/insects/cicada.dart', id: 'fake/id/6'),
  ScriptRef(uri: 'kitchen:food/catering/party.dart', id: 'fake/id/7'),
  ScriptRef(uri: 'kitchen:food/carton/milk.dart', id: 'fake/id/8'),
  ScriptRef(uri: 'kitchen:food/milk/carton.dart', id: 'fake/id/9'),
  ScriptRef(uri: 'travel:adventure/cave_tours_europe.dart', id: 'fake/id/10'),
  ScriptRef(uri: 'travel:canada/banff.dart', id: 'fake/id/11'),
];
