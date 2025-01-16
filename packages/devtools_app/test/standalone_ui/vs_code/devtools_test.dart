// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:devtools_app/src/shared/editor/api_classes.dart';
import 'package:devtools_app/src/standalone_ui/vs_code/devtools/devtools_view.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/utils/sidebar_utils.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);
  const testDtdProjectRoot = '/Users/me/package_root_1/';

  late MockEditorClient mockEditorClient;

  setUpAll(() {
    // Set test mode so that the debug list of extensions will be used.
    setTestMode();
  });

  // ignore: avoid-redundant-async, false positive.
  setUp(() async {
    mockEditorClient = MockEditorClient();
    when(mockEditorClient.supportsGetDevices).thenReturn(true);
    when(mockEditorClient.supportsSelectDevice).thenReturn(true);
    when(mockEditorClient.supportsOpenDevToolsPage).thenReturn(true);
    when(mockEditorClient.supportsOpenDevToolsForceExternal).thenReturn(true);
    when(mockEditorClient.supportsHotReload).thenReturn(true);
    when(mockEditorClient.supportsHotRestart).thenReturn(true);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());

    final mockDtdManager = MockDTDManager();
    when(
      mockDtdManager.projectRoots(
        depth: staticExtensionsSearchDepth,
        forceRefresh: true,
      ),
    ).thenAnswer((_) async {
      return UriList(uris: [Uri.file(testDtdProjectRoot)]);
    });
    when(mockDtdManager.hasConnection).thenReturn(true);
    setGlobal(DTDManager, mockDtdManager);
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
    for (final hasDebugSessions in [true, false]) {
      final debugSessions =
          hasDebugSessions
              ? {
                'test session': generateDebugSession(
                  debuggerType: 'Flutter',
                  deviceId: 'macos',
                  flutterMode: 'debug',
                  projectRootPath: testDtdProjectRoot,
                ),
              }
              : <String, EditorDebugSession>{};

      testWidgetsWithWindowSize(
        'pumps DevTools screens ${hasDebugSessions ? 'with' : 'without'} debug '
        'sessions',
        windowSize,
        (tester) async {
          await pumpDevToolsSidebarOptions(
            tester,
            debugSessions: debugSessions,
          );

          expect(find.text('DevTools'), findsOneWidget);
          for (final screen in ScreenMetaData.values) {
            final include = SidebarDevToolsScreens.includeInSidebar(screen);
            // Do not check the 'simple' or 'home' screens because they do not
            // have a title we can verify against.
            if (screen != ScreenMetaData.simple &&
                screen != ScreenMetaData.home) {
              expect(
                find.text(screen.title!),
                include ? findsOneWidget : findsNothing,
                reason: 'Unexpected find result for ${screen.id} screen.',
              );
            }

            if (include) {
              final buttonFinder = find.ancestor(
                of: find.text(screen.title!),
                matching: find.byType(InkWell),
              );
              expect(buttonFinder, findsOneWidget);
              final buttonWidget = tester.widget<InkWell>(buttonFinder);
              expect(
                buttonWidget.onTap,
                hasDebugSessions
                    ? isNotNull
                    : (screen.requiresConnection ? isNull : isNotNull),
              );
            }
          }
          expect(find.byIcon(Icons.open_in_browser_outlined), findsOneWidget);
        },
      );

      testWidgetsWithWindowSize('includes DevTools extensions', windowSize, (
        tester,
      ) async {
        await pumpDevToolsSidebarOptions(tester, debugSessions: debugSessions);
        expect(find.text('DevTools Extensions'), findsOneWidget);

        final expectedExtensions = [
          StubDevToolsExtensions.barExtension,
          StubDevToolsExtensions.bazExtension,
          StubDevToolsExtensions.duplicateFooExtension,
        ];
        for (final ext in expectedExtensions) {
          expect(find.text(ext.displayName), findsOneWidget);
          final buttonFinder = find.ancestor(
            of: find.text(ext.displayName),
            matching: find.byType(InkWell),
          );
          expect(buttonFinder, findsOneWidget);
          final buttonWidget = tester.widget<InkWell>(buttonFinder);
          expect(
            buttonWidget.onTap,
            hasDebugSessions
                ? isNotNull
                : (ext.requiresConnection ? isNull : isNotNull),
          );
        }
      });
    }
  });
}
