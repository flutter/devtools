// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/constants.dart';
import 'package:devtools_app/src/standalone_ui/api/impl/vs_code_api.dart';
import 'package:devtools_app/src/standalone_ui/api/vs_code_api.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/debug_sessions.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/test_data/dart_tooling_api/mock_api.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);

  late MockVsCodeApi mockVsCodeApi;
  late final Map<String, VsCodeDevice> deviceMap;

  setUpAll(() {
    // Set test mode so that the debug list of extensions will be used.
    setTestMode();

    final devices = stubbedDevices.map((d) => MapEntry(d.id, d));
    deviceMap = {for (final d in devices) d.key: d.value};
  });

  setUp(() {
    mockVsCodeApi = MockVsCodeApi();
    when(mockVsCodeApi.capabilities).thenReturn(
      VsCodeCapabilitiesImpl({
        'executeCommand': true,
        'selectDevice': true,
        'openDevToolsPage': true,
        'openDevToolsExternally': true,
        'hotReload': true,
        'hotRestart': true,
      }),
    );
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
  });

  Future<void> pumpDebugSessions(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        DebugSessions(
          api: mockVsCodeApi,
          sessions: _debugSessions,
          deviceMap: deviceMap,
        ),
      ),
    );
  }

  group('$DebugSessions', () {
    Finder iconButtonFinder(IconData icon, {required int index}) {
      return find
          .byWidgetPredicate(
            (widget) =>
                widget.runtimeType == IconButton &&
                ((widget as IconButton).icon as Icon).icon == icon,
          )
          .at(index);
    }

    void verifyDebugSessionState(
      WidgetTester tester, {
      required int debugSessionIndex,
      required String sessionDisplayText,
      required bool hotButtonsEnabled,
      required bool devtoolsButtonEnabled,
    }) {
      expect(find.text(sessionDisplayText), findsOneWidget);

      final hotReloadButtonFinder =
          iconButtonFinder(hotReloadIcon, index: debugSessionIndex);
      final hotRestartButtonFinder =
          iconButtonFinder(hotRestartIcon, index: debugSessionIndex);
      final devtoolsButtonFinder =
          iconButtonFinder(Icons.construction, index: debugSessionIndex);
      expect(hotReloadButtonFinder, findsOneWidget);
      expect(hotRestartButtonFinder, findsOneWidget);
      expect(devtoolsButtonFinder, findsOneWidget);

      final hotReloadButton =
          tester.widget(hotReloadButtonFinder) as IconButton;
      final hotRestartButton =
          tester.widget(hotRestartButtonFinder) as IconButton;
      final devtoolsMenuButton =
          tester.widget(devtoolsButtonFinder) as IconButton;
      expect(
        hotReloadButton.onPressed,
        hotButtonsEnabled ? isNotNull : isNull,
      );
      expect(
        hotRestartButton.onPressed,
        hotButtonsEnabled ? isNotNull : isNull,
      );
      expect(
        devtoolsMenuButton.onPressed,
        devtoolsButtonEnabled ? isNotNull : isNull,
      );
    }

    final tests = [
      (
        sessionDisplay: 'Session (Flutter) (macos) (debug)',
        hotButtonsEnabled: true,
        devtoolsButtonEnabled: true,
      ),
      (
        sessionDisplay: 'Session (Flutter) (macos) (profile)',
        hotButtonsEnabled: false,
        devtoolsButtonEnabled: true,
      ),
      (
        sessionDisplay: 'Session (Flutter) (macos) (release)',
        hotButtonsEnabled: false,
        devtoolsButtonEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Flutter) (macos) (jit_release)',
        hotButtonsEnabled: false,
        devtoolsButtonEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Flutter) (chrome) (debug)',
        hotButtonsEnabled: true,
        devtoolsButtonEnabled: true,
      ),
      (
        sessionDisplay: 'Session (Flutter) (chrome) (profile)',
        hotButtonsEnabled: false,
        devtoolsButtonEnabled: true,
      ),
      (
        sessionDisplay: 'Session (Flutter) (chrome) (release)',
        hotButtonsEnabled: false,
        devtoolsButtonEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Dart) (macos)',
        hotButtonsEnabled: true,
        devtoolsButtonEnabled: true,
      ),
    ];

    testWidgetsWithWindowSize(
      'rows render properly for run mode',
      windowSize,
      (tester) async {
        await pumpDebugSessions(tester);
        await tester.pump(const Duration(milliseconds: 500));
        for (var i = 0; i < tests.length; i++) {
          final test = tests[i];
          // ignore: avoid_print, defines individual test case.
          print('testing: ${test.sessionDisplay}');
          verifyDebugSessionState(
            tester,
            debugSessionIndex: i,
            sessionDisplayText: test.sessionDisplay,
            hotButtonsEnabled: test.hotButtonsEnabled,
            devtoolsButtonEnabled: test.devtoolsButtonEnabled,
          );
        }
      },
    );
  });
}

final _debugSessions = <VsCodeDebugSession>[
  // Flutter native apps.
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'macos',
    flutterMode: 'debug',
  ),
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'macos',
    flutterMode: 'profile',
  ),
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'macos',
    flutterMode: 'release',
  ),
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'macos',
    flutterMode: 'jit_release',
  ),
  // Flutter web apps.
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'chrome',
    flutterMode: 'debug',
  ),
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'chrome',
    flutterMode: 'profile',
  ),
  generateDebugSession(
    debuggerType: 'Flutter',
    deviceId: 'chrome',
    flutterMode: 'release',
  ),
  // Dart CLI app.
  generateDebugSession(
    debuggerType: 'Dart',
    deviceId: 'macos',
  ),
];

VsCodeDebugSession generateDebugSession({
  required String debuggerType,
  required String deviceId,
  String? flutterMode,
}) {
  return VsCodeDebugSessionImpl(
    id: '$debuggerType-$deviceId-$flutterMode',
    name: 'Session ($debuggerType) ($deviceId)',
    vmServiceUri: 'ws://127.0.0.1:1234/ws',
    flutterMode: flutterMode,
    flutterDeviceId: deviceId,
    debuggerType: debuggerType,
    projectRootPath: '/mock/root/path',
  );
}
