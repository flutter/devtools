// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/editor/api_classes.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/devtools.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);

  late MockEditorClient mockEditorClient;

  setUpAll(() {
    // Set test mode so that the debug list of extensions will be used.
    setTestMode();
  });

  setUp(() {
    mockEditorClient = MockEditorClient();
    when(mockEditorClient.supportsGetDevices).thenReturn(true);
    when(mockEditorClient.supportsSelectDevice).thenReturn(true);
    when(mockEditorClient.supportsOpenDevToolsPage).thenReturn(true);
    when(mockEditorClient.supportsOpenDevToolsExternally).thenReturn(true);
    when(mockEditorClient.supportsHotReload).thenReturn(true);
    when(mockEditorClient.supportsHotRestart).thenReturn(true);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
  });

  Future<void> pumpDevToolsSidebarOptions(
    WidgetTester tester, {
    Map<String, EditorDebugSession> debugSessions = const {},
  }) async {
    await tester.pumpWidget(
      wrap(
        DevToolsSidebarOptions(
          editor: mockEditorClient,
          debugSessions: debugSessions,
        ),
      ),
    );
    // Additional pump to allow for initializing the extensions service.
    await tester.pumpAndSettle();
  }

  group('$DevToolsSidebarOptions', () {
    testWidgetsWithWindowSize(
      'includes DevTools screens',
      windowSize,
      (tester) async {
        await pumpDevToolsSidebarOptions(tester);
        expect(find.text('DevTools'), findsOneWidget);
        for (final screen in ScreenMetaData.values) {
          final include = DevToolsSidebarOptions.includeInSidebar(screen);
          expect(
            find.text(screen.title!),
            include ? findsOneWidget : findsNothing,
          );
        }
        expect(find.byIcon(Icons.open_in_browser_outlined), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'includes DevTools extensions',
      windowSize,
      (tester) async {
        await pumpDevToolsSidebarOptions(tester);
        expect(find.text('DevTools Extensions'), findsOneWidget);
        expect(find.text('bar'), findsOneWidget);
      },
    );
  });
}
