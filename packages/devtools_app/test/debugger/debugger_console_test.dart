// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/test_utils.dart';

void main() {
  final fakeServiceConnection = FakeServiceConnectionManager();
  final debuggerController = createMockDebuggerControllerWithDefaults();

  const windowSize = Size(4000.0, 4000.0);

  when(fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow)
      .thenReturn(false);
  when(fakeServiceConnection.serviceManager.connectedApp!.isDartWebAppNow)
      .thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceConnection);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, MockScriptManager());
  setGlobal(NotificationService, NotificationService());
  setGlobal(EvalService, MockEvalService());
  setGlobal(
    DevToolsEnvironmentParameters,
    ExternalDevToolsEnvironmentParameters(),
  );
  setGlobal(PreferencesController, PreferencesController());
  fakeServiceConnection.consoleService.ensureServiceInitialized();
  when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));

  Future<void> pumpConsole(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        Row(
          children: [
            Flexible(child: ConsolePaneHeader()),
            const Expanded(child: ConsolePane()),
          ],
        ),
        debugger: controller,
      ),
    );
  }

  group('ConsoleControls', () {
    final stdio = ['First line', _ansiCodesOutput(), 'Third line'];

    void appendStdioLines() {
      for (final line in stdio) {
        serviceConnection.consoleService.appendStdio('$line\n');
      }
    }

    testWidgetsWithWindowSize(
      'Tapping the Console Clear button clears stdio.',
      windowSize,
      (WidgetTester tester) async {
        serviceConnection.consoleService.clearStdio();
        serviceConnection.consoleService.appendStdio(_ansiCodesOutput());

        await pumpConsole(tester, debuggerController);

        final clearButton = find.byKey(ConsolePane.clearStdioButtonKey);
        expect(clearButton, findsOneWidget);

        await tester.tap(clearButton);

        expect(serviceConnection.consoleService.stdio.value, isEmpty);
      },
    );

    group('Clipboard', () {
      String clipboardContents = '';
      final expected = stdio.join('\n');

      setUp(() {
        appendStdioLines();
        setupClipboardCopyListener(
          clipboardContentsCallback: (contents) {
            clipboardContents = contents ?? '';
          },
        );
      });

      tearDown(() {
        // Cleanup the SystemChannel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      testWidgetsWithWindowSize(
        'Tapping the Copy to Clipboard button attempts to copy stdio to clipboard.',
        windowSize,
        (WidgetTester tester) async {
          await pumpConsole(tester, debuggerController);

          final copyButton = find.byKey(ConsolePane.copyToClipboardButtonKey);
          expect(copyButton, findsOneWidget);

          expect(clipboardContents, isEmpty);

          await tester.tap(copyButton);

          expect(clipboardContents, equals(expected));
        },
      );
    });
  });
}

String _ansiCodesOutput() {
  final sb = StringBuffer();
  sb.write('Ansi color codes processed for ');
  final pen = AnsiPen()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
  sb.write(pen('console'));
  return sb.toString();
}
