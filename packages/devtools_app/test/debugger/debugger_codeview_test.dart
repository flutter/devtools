// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../matchers/matchers.dart';

void main() {
  const mockScriptRefFileUri = 'the/path/mapped/to/script/ref/uri';
  late FakeServiceManager fakeServiceManager;
  late MockDebuggerController debuggerController;
  late ScriptsHistory scriptsHistory;

  const smallWindowSize = Size(1000.0, 1000.0);

  setUpAll(() {
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        resolvedUriMap: {mockScriptRefFileUri: mockScriptRef.uri!},
      ),
    );
    debuggerController = createMockDebuggerControllerWithDefaults();
    scriptsHistory = ScriptsHistory();

    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, MockScriptManager());
    fakeServiceManager.consoleService.ensureServiceInitialized();
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));

    scriptsHistory.pushEntry(mockScript!);
    when(debuggerController.currentScriptRef)
        .thenReturn(ValueNotifier(mockScriptRef));
    when(debuggerController.currentParsedScript)
        .thenReturn(ValueNotifier(mockParsedScript));
    when(debuggerController.showSearchInFileField)
        .thenReturn(ValueNotifier(false));
    when(debuggerController.showFileOpener).thenReturn(ValueNotifier(false));
    when(debuggerController.scriptsHistory).thenReturn(scriptsHistory);
    when(debuggerController.searchMatches).thenReturn(ValueNotifier([]));
    when(debuggerController.activeSearchMatch).thenReturn(ValueNotifier(null));
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ),
    );
  }

  testWidgetsWithWindowSize(
      'has a horizontal and a vertical scrollbar', smallWindowSize,
      (WidgetTester tester) async {
    await pumpDebuggerScreen(tester, debuggerController);

    // TODO(elliette): https://github.com/flutter/flutter/pull/88152 fixes
    // this so that forcing a scroll event is no longer necessary. Remove
    // once the change is in the stable release.
    debuggerController.showScriptLocation(
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
      find.byKey(DebuggerScreenBody.codeViewKey),
      matchesDevToolsGolden('../goldens/codeview_scrollbars.png'),
    );
  });

  group('fetchScriptLocationFullFilePath', () {
    testWidgets('gets the full path', (WidgetTester tester) async {
      when(debuggerController.scriptLocation).thenReturn(
        ValueNotifier(
          ScriptLocation(
            mockScriptRef,
            location: const SourcePosition(line: 50, column: 50),
          ),
        ),
      );

      final filePath =
          await fetchScriptLocationFullFilePath(debuggerController);

      expect(filePath, equals(mockScriptRefFileUri));
    });

    testWidgets('gets the path if immediately available',
        (WidgetTester tester) async {
      when(debuggerController.scriptLocation).thenReturn(
        ValueNotifier(
          ScriptLocation(
            mockScriptRef,
            location: const SourcePosition(line: 50, column: 50),
          ),
        ),
      );
      // Prefetch File Uris
      await serviceManager.resolvedUriManager.fetchFileUris(
        serviceManager.isolateManager.selectedIsolate.value!.id!,
        [mockScriptRef.uri!],
      );

      final filePath =
          await fetchScriptLocationFullFilePath(debuggerController);

      expect(filePath, equals(mockScriptRefFileUri));
    });

    testWidgets('returns null if package not found',
        (WidgetTester tester) async {
      when(debuggerController.scriptLocation).thenReturn(
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
          await fetchScriptLocationFullFilePath(debuggerController);

      expect(filePath, isNull);
    });
  });
}
