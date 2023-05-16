// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/test_utils.dart';

void main() {
  late CodeViewController codeViewController;
  late MockDebuggerController mockDebuggerController;

  const smallWindowSize = Size(1200.0, 1000.0);

  void initializeGlobalsAndMockApp() {
    final fakeServiceManager = FakeServiceManager();
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, MockScriptManager());
    setGlobal(NotificationService, NotificationService());
    setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
    setGlobal(PreferencesController, PreferencesController());

    mockConnectedApp(
      fakeServiceManager.connectedApp!,
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
        const DebuggerScreenBody(),
        debugger: controller,
      ),
    );
  }

  setUpAll(() {
    initializeGlobalsAndMockApp();
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

        codeViewController.showScriptLocation(
          ScriptLocation(
            mockScriptRef,
            location: const SourcePosition(line: 1, column: 1),
          ),
        );

        await tester.pumpAndSettle();

        expectFirstNLinesContain(
          [
            '// Copyright 2019 The Flutter team. All rights reserved',
            '// Use of this source code is governed by a BSD-style license that can be',
            '// found in the LICENSE file.',
          ],
        );
      },
      skip: true,
    );

    testWidgetsWithWindowSize(
      'script name is visible',
      smallWindowSize,
      (WidgetTester tester) async {
        await pumpDebuggerScreen(tester, mockDebuggerController);

        codeViewController.showScriptLocation(
          ScriptLocation(
            mockScriptRef,
            location: const SourcePosition(line: 1, column: 1),
          ),
        );

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

        codeViewController.showScriptLocation(
          ScriptLocation(
            mockLargeScriptRef,
            location: const SourcePosition(line: 1, column: 1),
          ),
        );

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

        codeViewController.showScriptLocation(
          ScriptLocation(
            mockLargeScriptRef,
            location: const SourcePosition(line: 1, column: 1),
          ),
        );

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
  });
}

void expectFirstNLinesContain(List<String> stringMatches) {
  final lines = find.byType(LineItem);
  for (int i = 0; i < stringMatches.length; i++) {
    final stringMatch = stringMatches[i];
    final line = getWidgetFromFinder<LineItem>(lines.at(i));
    expect(line.lineContents.toPlainText(), contains(stringMatch));
  }
}
