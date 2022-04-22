// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/console.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late FakeServiceManager fakeServiceManager;
  late MockDebuggerController debuggerController;
  late MockScriptManager scriptManager;

  const windowSize = Size(4000.0, 4000.0);

  setUp(() {
    fakeServiceManager = FakeServiceManager();
    scriptManager = MockScriptManager();
    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, scriptManager);
    fakeServiceManager.consoleService.ensureServiceInitialized();
    when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
        .thenReturn(ValueNotifier<int>(0));
    debuggerController = MockDebuggerController.withDefaults();
  });

  Future<void> pumpConsole(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        Row(
          children: [
            Flexible(child: DebuggerConsole.buildHeader()),
            const Expanded(child: DebuggerConsole()),
          ],
        ),
        debugger: controller,
      ),
    );
  }

  group('ConsoleControls', () {
    final _stdio = ['First line', _ansiCodesOutput(), 'Third line'];

    void _appendStdioLines() {
      for (var line in _stdio) {
        serviceManager.consoleService.appendStdio('$line\n');
      }
    }

    testWidgetsWithWindowSize(
        'Tapping the Console Clear button clears stdio.', windowSize,
        (WidgetTester tester) async {
      serviceManager.consoleService.clearStdio();
      serviceManager.consoleService.appendStdio(_ansiCodesOutput());

      await pumpConsole(tester, debuggerController);

      final clearButton = find.byKey(DebuggerConsole.clearStdioButtonKey);
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);

      expect(serviceManager.consoleService.stdio.value, isEmpty);
    });

    group('Clipboard', () {
      String _clipboardContents = '';
      final _expected = _stdio.join('\n');

      setUp(() {
        _appendStdioLines();
        // This intercepts the Clipboard.setData SystemChannel message,
        // and stores the contents that were (attempted) to be copied.
        SystemChannels.platform.setMockMethodCallHandler((MethodCall call) {
          switch (call.method) {
            case 'Clipboard.setData':
              _clipboardContents = call.arguments['text'];
              break;
            case 'Clipboard.getData':
              return Future.value(<String, dynamic>{});
            case 'Clipboard.hasStrings':
              return Future.value(<String, dynamic>{'value': true});
            default:
              break;
          }

          return Future.value(true);
        });
      });

      tearDown(() {
        // Cleanup the SystemChannel
        SystemChannels.platform.setMockMethodCallHandler(null);
      });

      testWidgetsWithWindowSize(
          'Tapping the Copy to Clipboard button attempts to copy stdio to clipboard.',
          windowSize, (WidgetTester tester) async {
        await pumpConsole(tester, debuggerController);

        final copyButton = find.byKey(DebuggerConsole.copyToClipboardButtonKey);
        expect(copyButton, findsOneWidget);

        expect(_clipboardContents, isEmpty);

        await tester.tap(copyButton);

        expect(_clipboardContents, equals(_expected));
      });
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
