// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/devtools_app.dart';
// ignore: implementation_imports, required to separate V2 inspector imports.
import 'package:devtools_app/src/screens/inspector_v2/inspector_controller.dart'
    as inspector_v2;
// ignore: implementation_imports, required to separate V2 inspector imports.
import 'package:devtools_app/src/shared/console/eval/inspector_tree_v2.dart'
    as inspector_v2;
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'generated_mocks_factories.dart';

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

  @override
  bool get hoverEvalModeEnabledByDefault => true;
}

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

class TestInspectorV2Controller extends Fake
    implements inspector_v2.InspectorController {
  InspectorService service = FakeInspectorService();

  @override
  ValueListenable<inspector_v2.InspectorTreeNode?> get selectedNode =>
      _selectedNode;
  final ValueNotifier<inspector_v2.InspectorTreeNode?> _selectedNode =
      ValueNotifier(null);

  @override
  void setSelectedNode(inspector_v2.InspectorTreeNode? newSelection) {
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

class TestCodeViewController extends CodeViewController {
  @override
  ProgramExplorerController get programExplorerController =>
      _explorerController;
  final _explorerController = createMockProgramExplorerControllerWithDefaults();
}

void mockWebVm(VM vm) {
  when(vm.targetCPU).thenReturn('Web');
  when(vm.architectureBits).thenReturn(-1);
  when(vm.operatingSystem).thenReturn('macos');
}

void mockConnectedApp(
  ConnectedApp connectedApp, {
  required bool isFlutterApp,
  required bool isProfileBuild,
  required bool isWebApp,
  String os = 'ios',
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

  // Operating system.
  when(connectedApp.operatingSystem).thenReturn(os);

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

// ignore: prefer_single_quotes, false positive.
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

final mockScriptRef = ScriptRef(
  uri: 'package:gallery/main.dart',
  id: 'test-script-long-lines',
);

final mockLargeScriptRef = ScriptRef(
  uri: 'package:front_end/src/fasta/kernel/body_builder.dart',
  id: 'test-large-script',
);

final mockEmptyScriptRef = ScriptRef(
  uri: 'package:gallery/src/unknown.dart',
  id: 'mock-script-no-source',
);

final Script? mockScript = _loadScript('script.json');

final Script? mockLargeScript = _loadScript('large_script.json');

final Script mockEmptyScript = Script(
  uri: 'package:gallery/src/unknown.dart',
  id: 'mock-script-no-source',
);

Script? _loadScript(String scriptName) {
  final script = File('../devtools_test/lib/src/mocks/mock_data/$scriptName');
  return Script.parse(jsonDecode(script.readAsStringSync()));
}

final mockSyntaxHighlighter = SyntaxHighlighter.withGrammar(
  grammar: mockGrammar,
  source: mockScript!.source,
);

const coverageHitLines = <int>{
  1,
  3,
  4,
  7,
};

const coverageMissLines = <int>{
  2,
  5,
};

const executableLines = <int>{
  ...coverageHitLines,
  ...coverageMissLines,
};

const profilerEntries = <int, ProfileReportEntry>{
  1: ProfileReportEntry(
    sampleCount: 5,
    line: 1,
    inclusive: 2,
    exclusive: 2,
  ),
  3: ProfileReportEntry(
    sampleCount: 5,
    line: 3,
    inclusive: 1,
    exclusive: 1,
  ),
  4: ProfileReportEntry(
    sampleCount: 5,
    line: 4,
    inclusive: 1,
    exclusive: 1,
  ),
  7: ProfileReportEntry(
    sampleCount: 5,
    line: 7,
    inclusive: 1,
    exclusive: 1,
  ),
};

final mockParsedScript = ParsedScript(
  script: mockScript!,
  highlighter: mockSyntaxHighlighter,
  executableLines: executableLines,
  sourceReport: ProcessedSourceReport(
    coverageHitLines: coverageHitLines,
    coverageMissedLines: coverageMissLines,
    profilerEntries: profilerEntries,
  ),
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
