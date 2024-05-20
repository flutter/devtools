// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/standalone_ui/api/impl/vs_code_api.dart';
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

  late MockVsCodeApi mockVsCodeApi;

  setUpAll(() {
    // Set test mode so that the debug list of extensions will be used.
    setTestMode();
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

  Future<void> pumpDevToolsSidebarOptions(
    WidgetTester tester, {
    bool hasDebugSessions = false,
  }) async {
    await tester.pumpWidget(
      wrap(
        DevToolsSidebarOptions(
          api: mockVsCodeApi,
          hasDebugSessions: hasDebugSessions,
        ),
      ),
    );
    // Additional pump to allow for initializing the extensions service.
    await tester.pumpAndSettle();
  }

  group('$DevToolsSidebarOptions', () {
    testWidgetsWithWindowSize(
      'includes static DevTools screens',
      windowSize,
      (tester) async {
        await pumpDevToolsSidebarOptions(tester);
        expect(find.text('DevTools'), findsOneWidget);
        expect(find.text(ScreenMetaData.appSize.title!), findsOneWidget);
        expect(find.text(ScreenMetaData.deepLinks.title!), findsOneWidget);
        expect(find.text('Open in Browser'), findsOneWidget);
        expect(
          find.text(
            'Begin a debug session to use tools that require a running '
            'application.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'includes DevTools extensions',
      windowSize,
      (tester) async {
        await pumpDevToolsSidebarOptions(tester);
        expect(find.text('DevTools Extensions'), findsOneWidget);
        expect(find.text('bar'), findsOneWidget);
        expect(
          find.text(
            'Begin a debug session to use extensions that require a running '
            'application.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'changes runtime tool instructions with non-empty debug sessions',
      windowSize,
      (tester) async {
        await pumpDevToolsSidebarOptions(tester, hasDebugSessions: true);
        expect(
          find.text(
            'Open the tools menu for a debug session to access tools that '
            'require a running application.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Open the tools menu for a debug session to access extensions that '
            'require a running application.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
