// Copyright 2023 The Chromium Authors. All rights reserved.
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

import '../test_infra/utils/test_utils.dart';

void main() {
  late CodeViewController codeViewController;
  late MockDebuggerController mockDebuggerController;

  const smallWindowSize = Size(1200.0, 1000.0);

  void initializeGlobalsAndMockApp() {
    final fakeServiceConnection = FakeServiceConnectionManager();
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, MockScriptManager());
    setGlobal(NotificationService, NotificationService());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());

    mockConnectedApp(
      fakeServiceConnection.serviceManager.connectedApp!,
      isProfileBuild: false,
      isFlutterApp: true,
      isWebApp: false,
    );
  }

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

  Future<void> showScript(ScriptRef scriptRef) async {
    await codeViewController.showScriptLocation(
      ScriptLocation(
        scriptRef,
        location: const SourcePosition(line: 1, column: 1),
      ),
    );
  }

  setUpAll(() async {
    initializeGlobalsAndMockApp();
    await SyntaxHighlighter.initialize();
    codeViewController = CodeViewController();
    mockDebuggerController = createMockDebuggerControllerWithDefaults(
      codeViewController: codeViewController,
    );
  });

  group('for a script with < 100000 lines', () {
    setUpAll(() {
      when(scriptManager.getScriptCached(mockScriptRef)).thenReturn(mockScript);
    });

    testWidgetsWithWindowSize(
      'lines of the script are visible',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockScriptRef);
        await tester.pumpAndSettle();

        expectFirstNLinesContain(
          [
            '// Copyright 2019 The Flutter team. All rights reserved',
            '// Use of this source code is governed by a BSD-style license that can be',
            '// found in the LICENSE file.',
          ],
        );
      },
    );

    testWidgetsWithWindowSize(
      'lines of the script are highlighted',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockScriptRef);
        await tester.pumpAndSettle();

        expect(firstNLinesAreHighlighted(10), isTrue);
      },
    );

    testWidgetsWithWindowSize(
      'script name is visible',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockScriptRef);
        await tester.pumpAndSettle();

        expect(
          find.text('package:gallery/main.dart'),
          findsOneWidget,
        );
      },
    );
  });

  group('for a script with > 100000 lines', () {
    setUpAll(() {
      when(scriptManager.getScriptCached(mockLargeScriptRef))
          .thenReturn(mockLargeScript);
    });

    testWidgetsWithWindowSize(
      'script name is visible',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockLargeScriptRef);
        await tester.pumpAndSettle();

        expect(
          find.text('package:front_end/src/fasta/kernel/body_builder.dart'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'lines of the script are visible',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockLargeScriptRef);
        await tester.pumpAndSettle();

        expectFirstNLinesContain(
          [
            '// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file',
            '// for details. All rights reserved. Use of this source code is governed by a',
            '// BSD-style license that can be found in the LICENSE file.',
          ],
        );
      },
    );

    testWidgetsWithWindowSize(
      'lines of the script are not highlighted',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockLargeScriptRef);
        await tester.pumpAndSettle();

        expect(firstNLinesAreHighlighted(10), isFalse);
      },
    );
  });

  group('for a script with no source', () {
    setUpAll(() {
      when(scriptManager.getScriptCached(mockScriptRef)).thenReturn(mockScript);
      when(scriptManager.getScriptCached(mockEmptyScriptRef))
          .thenReturn(mockEmptyScript);
    });

    testWidgetsWithWindowSize(
      'script name does not update',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockScriptRef);
        await tester.pumpAndSettle();

        expect(
          find.text('package:gallery/main.dart'),
          findsOneWidget,
        );

        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockEmptyScriptRef);
        await tester.pumpAndSettle();

        expect(
          find.text('package:gallery/main.dart'),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'lines of the script do not update',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockScriptRef);
        await tester.pumpAndSettle();

        expectFirstNLinesContain(
          [
            '// Copyright 2019 The Flutter team. All rights reserved',
            '// Use of this source code is governed by a BSD-style license that can be',
            '// found in the LICENSE file.',
          ],
        );

        await pumpDebuggerScreen(tester, mockDebuggerController);
        await showScript(mockEmptyScriptRef);
        await tester.pumpAndSettle();

        expectFirstNLinesContain(
          [
            '// Copyright 2019 The Flutter team. All rights reserved',
            '// Use of this source code is governed by a BSD-style license that can be',
            '// found in the LICENSE file.',
          ],
        );
      },
    );

    testWidgetsWithWindowSize(
      'an error message is shown',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);
        // Dismiss any previous notifications:
        notificationService
            .dismiss('Failed to parse package:gallery/src/unknown.dart.');
        await tester.pumpAndSettle();

        await showScript(mockEmptyScriptRef);
        await tester.pumpAndSettle();

        expect(
          notificationService.activeMessages.first.text,
          equals('Failed to parse package:gallery/src/unknown.dart.'),
        );
      },
    );
  });
}

bool firstNLinesAreHighlighted(int n) {
  bool containsNonHighlightedLine = false;
  final lines = find.byType(LineItem);
  for (int i = 0; i < n; i++) {
    final line = getWidgetFromFinder<LineItem>(lines.at(i));
    if (line.lineContents.children == null) {
      containsNonHighlightedLine = true;
    }
  }
  return !containsNonHighlightedLine;
}

void expectFirstNLinesContain(List<String> stringMatches) {
  final lines = find.byType(LineItem);
  expect(lines, findsAtLeastNWidgets(stringMatches.length));
  for (int i = 0; i < stringMatches.length; i++) {
    final stringMatch = stringMatches[i];
    final line = getWidgetFromFinder<LineItem>(lines.at(i));
    expect(line.lineContents.toPlainText(), contains(stringMatch));
  }
}
