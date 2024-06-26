// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/matchers/matchers.dart';

void main() {
  const mockScriptRefFileUri = 'the/path/mapped/to/script/ref/uri';
  late FakeServiceConnectionManager fakeServiceConnection;
  late MockDebuggerController debuggerController;
  late MockCodeViewController codeViewController;
  late ScriptsHistory scriptsHistory;

  const smallWindowSize = Size(1200.0, 1000.0);

  setUpAll(() {
    setGlobal(BreakpointManager, BreakpointManager());
    fakeServiceConnection = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        resolvedUriMap: {mockScriptRefFileUri: mockScriptRef.uri!},
      ),
    );
    codeViewController = createMockCodeViewControllerWithDefaults();
    debuggerController = createMockDebuggerControllerWithDefaults(
      codeViewController: codeViewController,
    );
    scriptsHistory = ScriptsHistory();
    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isProfileBuild: false,
      isFlutterApp: true,
      isWebApp: false,
    );
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, MockScriptManager());
    setGlobal(NotificationService, NotificationService());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    fakeServiceConnection.consoleService.ensureServiceInitialized();
    when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));

    scriptsHistory.pushEntry(mockScript!);
    final mockCodeViewController = debuggerController.codeViewController;
    when(mockCodeViewController.currentScriptRef)
        .thenReturn(ValueNotifier(mockScriptRef));
    when(mockCodeViewController.currentParsedScript)
        .thenReturn(ValueNotifier(mockParsedScript));
    when(mockCodeViewController.scriptsHistory).thenReturn(scriptsHistory);
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        DebuggerSourceAndControls(
          shownFirstScript: () => true,
          setShownFirstScript: (_) {},
        ),
        debugger: controller,
      ),
    );
  }

  testWidgetsWithWindowSize(
    'has a horizontal and a vertical scrollbar',
    smallWindowSize,
    (WidgetTester tester) async {
      await pumpDebuggerScreen(tester, debuggerController);

      await codeViewController.showScriptLocation(
        ScriptLocation(
          mockScriptRef,
          location: const SourcePosition(line: 50, column: 50),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsNWidgets(2));
      expect(
        find.byKey(const Key('debuggerCodeViewVerticalScrollbarKey')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('debuggerCodeViewHorizontalScrollbarKey')),
        findsOneWidget,
      );
      await expectLater(
        find.byType(CodeView),
        matchesDevToolsGolden(
          '../test_infra/goldens/codeview_scrollbars.png',
        ),
      );
    },
  );

  testWidgetsWithWindowSize(
    'search in file field is visible',
    smallWindowSize,
    (WidgetTester tester) async {
      when(codeViewController.showSearchInFileField)
          .thenReturn(ValueNotifier(true));
      when(codeViewController.searchFieldFocusNode).thenReturn(FocusNode());
      when(codeViewController.searchTextFieldController)
          .thenReturn(SearchTextEditingController());

      await pumpDebuggerScreen(tester, debuggerController);
      expect(find.byType(SearchField<CodeViewController>), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'file opener is visible',
    smallWindowSize,
    (WidgetTester tester) async {
      when(codeViewController.showFileOpener).thenReturn(ValueNotifier(true));
      when(scriptManager.sortedScripts).thenReturn(ValueNotifier([]));
      await pumpDebuggerScreen(tester, debuggerController);
      expect(
        find.byKey(debuggerCodeViewFileOpenerKey),
        findsOneWidget,
      );
    },
  );

  group('fetchScriptLocationFullFilePath', () {
    testWidgets('gets the full path', (WidgetTester tester) async {
      when(codeViewController.scriptLocation).thenReturn(
        ValueNotifier(
          ScriptLocation(
            mockScriptRef,
            location: const SourcePosition(line: 50, column: 50),
          ),
        ),
      );

      final filePath =
          await fetchScriptLocationFullFilePath(codeViewController);

      expect(filePath, equals(mockScriptRefFileUri));
    });

    testWidgets(
      'gets the path if immediately available',
      (WidgetTester tester) async {
        when(codeViewController.scriptLocation).thenReturn(
          ValueNotifier(
            ScriptLocation(
              mockScriptRef,
              location: const SourcePosition(line: 50, column: 50),
            ),
          ),
        );
        // Prefetch File Uris
        await serviceConnection.serviceManager.resolvedUriManager.fetchFileUris(
          serviceConnection
              .serviceManager.isolateManager.selectedIsolate.value!.id!,
          [mockScriptRef.uri!],
        );

        final filePath =
            await fetchScriptLocationFullFilePath(codeViewController);

        expect(filePath, equals(mockScriptRefFileUri));
      },
    );

    testWidgets(
      'returns null if package not found',
      (WidgetTester tester) async {
        when(codeViewController.scriptLocation).thenReturn(
          ValueNotifier(
            ScriptLocation(
              ScriptRef(
                uri: 'some/unknown/file',
                id: 'unknown-script-ref-for-test',
              ),
              location: const SourcePosition(line: 123, column: 456),
            ),
          ),
        );

        final filePath =
            await fetchScriptLocationFullFilePath(codeViewController);

        expect(filePath, isNull);
      },
    );
  });
}
