// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/constants.dart';
import 'package:devtools_app/src/shared/editor/api_classes.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/debug_sessions.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/scenes/standalone_ui/editor_service/simulated_editor.dart';
import '../../test_infra/utils/sidebar_utils.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);

  late MockEditorClient mockEditorClient;
  late final Map<String, EditorDevice> deviceMap;

  setUpAll(() {
    // Set test mode so that the debug list of extensions will be used.
    setTestMode();
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());

    final devices = stubbedDevices.map((d) => MapEntry(d.id, d));
    deviceMap = {for (final d in devices) d.key: d.value};
  });

  setUp(() {
    mockEditorClient = MockEditorClient();
    when(mockEditorClient.supportsGetDevices).thenReturn(true);
    when(mockEditorClient.supportsSelectDevice).thenReturn(true);
    when(mockEditorClient.supportsOpenDevToolsPage).thenReturn(true);
    when(mockEditorClient.supportsOpenDevToolsForceExternal).thenReturn(true);
    when(mockEditorClient.supportsHotReload).thenReturn(true);
    when(mockEditorClient.supportsHotRestart).thenReturn(true);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
  });

  Future<void> pumpDebugSessions(WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        DebugSessions(
          editor: mockEditorClient,
          sessions: Map.fromEntries(
            _debugSessions.map((s) => MapEntry(s.id, s)),
          ),
          devices: deviceMap,
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
    }) {
      expect(find.text(sessionDisplayText), findsOneWidget);

      final hotReloadButtonFinder = iconButtonFinder(
        hotReloadIcon,
        index: debugSessionIndex,
      );
      final hotRestartButtonFinder = iconButtonFinder(
        hotRestartIcon,
        index: debugSessionIndex,
      );
      expect(hotReloadButtonFinder, findsOneWidget);
      expect(hotRestartButtonFinder, findsOneWidget);

      final hotReloadButton =
          tester.widget(hotReloadButtonFinder) as IconButton;
      final hotRestartButton =
          tester.widget(hotRestartButtonFinder) as IconButton;
      expect(hotReloadButton.onPressed, hotButtonsEnabled ? isNotNull : isNull);
      expect(
        hotRestartButton.onPressed,
        hotButtonsEnabled ? isNotNull : isNull,
      );
    }

    final tests = [
      (
        sessionDisplay: 'Session (Flutter) (macos) (debug)',
        hotButtonsEnabled: true,
      ),
      (
        sessionDisplay: 'Session (Flutter) (macos) (profile)',
        hotButtonsEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Flutter) (macos) (release)',
        hotButtonsEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Flutter) (macos) (jit_release)',
        hotButtonsEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Flutter) (chrome) (debug)',
        hotButtonsEnabled: true,
      ),
      (
        sessionDisplay: 'Session (Flutter) (chrome) (profile)',
        hotButtonsEnabled: false,
      ),
      (
        sessionDisplay: 'Session (Flutter) (chrome) (release)',
        hotButtonsEnabled: false,
      ),
      (sessionDisplay: 'Session (Dart) (macos)', hotButtonsEnabled: true),
    ];

    testWidgetsWithWindowSize('rows render properly for run mode', windowSize, (
      tester,
    ) async {
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
        );
      }
    });
  });
}

final _debugSessions = [
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
  generateDebugSession(debuggerType: 'Dart', deviceId: 'macos'),
];
