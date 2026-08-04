// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/controls.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  /// Widths the debugging controls are expected to lay out at without
  /// overflowing.
  ///
  /// The controls stop showing button labels below
  /// [DebuggingControls.minWidth], but the remaining icon-only content still
  /// did not fit below roughly 630px, which is a realistic width for DevTools
  /// embedded in an IDE side panel. See
  /// https://github.com/flutter/devtools/issues/4917.
  const windowWidths = [1200.0, 800.0, 600.0, 500.0, 400.0];

  const windowHeight = 800.0;

  final fakeServiceConnection = FakeServiceConnectionManager();
  final scriptManager = MockScriptManager();
  mockConnectedApp(fakeServiceConnection.serviceManager.connectedApp!);
  setGlobal(ServiceConnectionManager, fakeServiceConnection);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(NotificationService, NotificationService());
  setGlobal(BreakpointManager, BreakpointManager());
  setGlobal(
    DevToolsEnvironmentParameters,
    ExternalDevToolsEnvironmentParameters(),
  );
  setGlobal(PreferencesController, PreferencesController());
  fakeServiceConnection.consoleService.ensureServiceInitialized();
  when(
    fakeServiceConnection.errorBadgeManager.errorCountNotifier('debugger'),
  ).thenReturn(ValueNotifier<int>(0));
  final debuggerController = createMockDebuggerControllerWithDefaults();

  Future<void> pumpControls(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggingControls(),
        debugger: debuggerController,
      ),
    );
    await tester.pump();
  }

  group('DebuggingControls', () {
    for (final width in windowWidths) {
      testWidgetsWithWindowSize(
        'does not overflow at ${width.toInt()}px',
        Size(width, windowHeight),
        (WidgetTester tester) async {
          await pumpControls(tester);

          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgetsWithWindowSize(
      'keeps the file explorer button pinned to the right edge',
      const Size(1200.0, windowHeight),
      (WidgetTester tester) async {
        await pumpControls(tester);

        final controlsRight = tester
            .getRect(find.byType(DebuggingControls))
            .right;
        final fileExplorerButtonRight = tester
            .getRect(
              find.widgetWithIcon(GaDevToolsButton, Icons.folder_outlined),
            )
            .right;

        expect(fileExplorerButtonRight, equals(controlsRight));
      },
    );
  });
}
