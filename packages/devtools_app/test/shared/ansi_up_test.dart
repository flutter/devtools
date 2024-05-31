// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('chrome')
library;

import 'package:ansi_up/ansi_up.dart';
import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('ansi_up', () {
    test('test standard colors', () {
      final pen = AnsiPen();
      final sb = StringBuffer();
      // Test the 16 color defaults.
      for (int c = 0; c < 16; c++) {
        pen
          ..reset()
          ..white(bold: true)
          ..xterm(c, bg: true);
        sb.write(pen('$c '));
        pen
          ..reset()
          ..xterm(c);
        sb.write(pen(' $c '));
        if (c == 7 || c == 15) {
          sb.writeln();
        }
      }

      // Test a few custom colors.
      for (int r = 0; r < 6; r += 3) {
        sb.writeln();
        for (int g = 0; g < 6; g += 3) {
          for (int b = 0; b < 6; b += 3) {
            final c = r * 36 + g * 6 + b + 16;
            pen
              ..reset()
              ..rgb(r: r / 5, g: g / 5, b: b / 5, bg: true)
              ..white(bold: true);
            sb.write(pen(' $c '));
            pen
              ..reset()
              ..rgb(r: r / 5, g: g / 5, b: b / 5);
            sb.write(pen(' $c '));
          }
          sb.writeln();
        }
      }

      for (int c = 0; c < 24; c++) {
        if (0 == c % 8) {
          sb.writeln();
        }
        pen
          ..reset()
          ..gray(level: c / 23, bg: true)
          ..white(bold: true);
        sb.write(pen(' ${c + 232} '));
        pen
          ..reset()
          ..gray(level: c / 23);
        sb.write(pen(' ${c + 232} '));
      }

      final output = StringBuffer();
      for (var entry in decodeAnsiColorEscapeCodes(sb.toString(), AnsiUp())) {
        if (entry.style.isNotEmpty) {
          output.write("<span style='${entry.style}'>${entry.text}</span>");
        } else {
          output.write(entry.text);
          // TODO: Note that we are not handling links yet.
        }
      }
      expect(
        output.toString(),
        equals(
          '<span style=\'background-color: rgb(0,0,0);color: rgb(255,255,255)\'>0 </span><span style=\'color: rgb(0,0,0)\'> 0 </span><span style=\'background-color: rgb(187,0,0);color: rgb(255,255,255)\'>1 </span><span style=\'color: rgb(187,0,0)\'> 1 </span><span style=\'background-color: rgb(0,187,0);color: rgb(255,255,255)\'>2 </span><span style=\'color: rgb(0,187,0)\'> 2 </span><span style=\'background-color: rgb(187,187,0);color: rgb(255,255,255)\'>3 </span><span style=\'color: rgb(187,187,0)\'> 3 </span><span style=\'background-color: rgb(0,0,187);color: rgb(255,255,255)\'>4 </span><span style=\'color: rgb(0,0,187)\'> 4 </span><span style=\'background-color: rgb(187,0,187);color: rgb(255,255,255)\'>5 </span><span style=\'color: rgb(187,0,187)\'> 5 </span><span style=\'background-color: rgb(0,187,187);color: rgb(255,255,255)\'>6 </span><span style=\'color: rgb(0,187,187)\'> 6 </span><span style=\'background-color: rgb(255,255,255);color: rgb(255,255,255)\'>7 </span><span style=\'color: rgb(255,255,255)\'> 7 </span>\n'
          '<span style=\'background-color: rgb(85,85,85);color: rgb(255,255,255)\'>8 </span><span style=\'color: rgb(85,85,85)\'> 8 </span><span style=\'background-color: rgb(255,85,85);color: rgb(255,255,255)\'>9 </span><span style=\'color: rgb(255,85,85)\'> 9 </span><span style=\'background-color: rgb(0,255,0);color: rgb(255,255,255)\'>10 </span><span style=\'color: rgb(0,255,0)\'> 10 </span><span style=\'background-color: rgb(255,255,85);color: rgb(255,255,255)\'>11 </span><span style=\'color: rgb(255,255,85)\'> 11 </span><span style=\'background-color: rgb(85,85,255);color: rgb(255,255,255)\'>12 </span><span style=\'color: rgb(85,85,255)\'> 12 </span><span style=\'background-color: rgb(255,85,255);color: rgb(255,255,255)\'>13 </span><span style=\'color: rgb(255,85,255)\'> 13 </span><span style=\'background-color: rgb(85,255,255);color: rgb(255,255,255)\'>14 </span><span style=\'color: rgb(85,255,255)\'> 14 </span><span style=\'background-color: rgb(255,255,255);color: rgb(255,255,255)\'>15 </span><span style=\'color: rgb(255,255,255)\'> 15 </span>\n'
          '\n'
          '<span style=\'background-color: rgb(0,0,0);color: rgb(255,255,255)\'> 16 </span><span style=\'color: rgb(0,0,0)\'> 16 </span><span style=\'background-color: rgb(0,0,175);color: rgb(255,255,255)\'> 19 </span><span style=\'color: rgb(0,0,175)\'> 19 </span>\n'
          '<span style=\'background-color: rgb(0,175,0);color: rgb(255,255,255)\'> 34 </span><span style=\'color: rgb(0,175,0)\'> 34 </span><span style=\'background-color: rgb(0,175,175);color: rgb(255,255,255)\'> 37 </span><span style=\'color: rgb(0,175,175)\'> 37 </span>\n'
          '\n'
          '<span style=\'background-color: rgb(175,0,0);color: rgb(255,255,255)\'> 124 </span><span style=\'color: rgb(175,0,0)\'> 124 </span><span style=\'background-color: rgb(175,0,175);color: rgb(255,255,255)\'> 127 </span><span style=\'color: rgb(175,0,175)\'> 127 </span>\n'
          '<span style=\'background-color: rgb(175,175,0);color: rgb(255,255,255)\'> 142 </span><span style=\'color: rgb(175,175,0)\'> 142 </span><span style=\'background-color: rgb(175,175,175);color: rgb(255,255,255)\'> 145 </span><span style=\'color: rgb(175,175,175)\'> 145 </span>\n'
          '\n'
          '<span style=\'background-color: rgb(8,8,8);color: rgb(255,255,255)\'> 232 </span><span style=\'color: rgb(8,8,8)\'> 232 </span><span style=\'background-color: rgb(18,18,18);color: rgb(255,255,255)\'> 233 </span><span style=\'color: rgb(18,18,18)\'> 233 </span><span style=\'background-color: rgb(28,28,28);color: rgb(255,255,255)\'> 234 </span><span style=\'color: rgb(28,28,28)\'> 234 </span><span style=\'background-color: rgb(38,38,38);color: rgb(255,255,255)\'> 235 </span><span style=\'color: rgb(38,38,38)\'> 235 </span><span style=\'background-color: rgb(48,48,48);color: rgb(255,255,255)\'> 236 </span><span style=\'color: rgb(48,48,48)\'> 236 </span><span style=\'background-color: rgb(58,58,58);color: rgb(255,255,255)\'> 237 </span><span style=\'color: rgb(58,58,58)\'> 237 </span><span style=\'background-color: rgb(68,68,68);color: rgb(255,255,255)\'> 238 </span><span style=\'color: rgb(68,68,68)\'> 238 </span><span style=\'background-color: rgb(78,78,78);color: rgb(255,255,255)\'> 239 </span><span style=\'color: rgb(78,78,78)\'> 239 </span>\n'
          '<span style=\'background-color: rgb(88,88,88);color: rgb(255,255,255)\'> 240 </span><span style=\'color: rgb(88,88,88)\'> 240 </span><span style=\'background-color: rgb(98,98,98);color: rgb(255,255,255)\'> 241 </span><span style=\'color: rgb(98,98,98)\'> 241 </span><span style=\'background-color: rgb(108,108,108);color: rgb(255,255,255)\'> 242 </span><span style=\'color: rgb(108,108,108)\'> 242 </span><span style=\'background-color: rgb(118,118,118);color: rgb(255,255,255)\'> 243 </span><span style=\'color: rgb(118,118,118)\'> 243 </span><span style=\'background-color: rgb(128,128,128);color: rgb(255,255,255)\'> 244 </span><span style=\'color: rgb(128,128,128)\'> 244 </span><span style=\'background-color: rgb(138,138,138);color: rgb(255,255,255)\'> 245 </span><span style=\'color: rgb(138,138,138)\'> 245 </span><span style=\'background-color: rgb(148,148,148);color: rgb(255,255,255)\'> 246 </span><span style=\'color: rgb(148,148,148)\'> 246 </span><span style=\'background-color: rgb(158,158,158);color: rgb(255,255,255)\'> 247 </span><span style=\'color: rgb(158,158,158)\'> 247 </span>\n'
          '<span style=\'background-color: rgb(168,168,168);color: rgb(255,255,255)\'> 248 </span><span style=\'color: rgb(168,168,168)\'> 248 </span><span style=\'background-color: rgb(178,178,178);color: rgb(255,255,255)\'> 249 </span><span style=\'color: rgb(178,178,178)\'> 249 </span><span style=\'background-color: rgb(188,188,188);color: rgb(255,255,255)\'> 250 </span><span style=\'color: rgb(188,188,188)\'> 250 </span><span style=\'background-color: rgb(198,198,198);color: rgb(255,255,255)\'> 251 </span><span style=\'color: rgb(198,198,198)\'> 251 </span><span style=\'background-color: rgb(208,208,208);color: rgb(255,255,255)\'> 252 </span><span style=\'color: rgb(208,208,208)\'> 252 </span><span style=\'background-color: rgb(218,218,218);color: rgb(255,255,255)\'> 253 </span><span style=\'color: rgb(218,218,218)\'> 253 </span><span style=\'background-color: rgb(228,228,228);color: rgb(255,255,255)\'> 254 </span><span style=\'color: rgb(228,228,228)\'> 254 </span><span style=\'background-color: rgb(238,238,238);color: rgb(255,255,255)\'> 255 </span><span style=\'color: rgb(238,238,238)\'> 255 </span>',
        ),
      );
    });
  });

  group('Logging Screen', () {
    late MockLoggingController mockLoggingController;
    late FakeServiceConnectionManager fakeServiceConnection;
    const windowSize = Size(1000.0, 1000.0);

    const totalLogs = 10;

    const nonJsonOutput = 'Non-json details for log number 8';
    const jsonOutput = '{\n"Details": "of log event 9",\n"logEvent": "9"\n}\n';

    String ansiCodesOutput() {
      final sb = StringBuffer();
      sb.write('Ansi color codes processed for ');
      final pen = AnsiPen()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
      sb.write(pen('log 5'));
      return sb.toString();
    }

    LogData generate(int i) {
      String? details = 'log event $i';
      String kind = 'kind $i';
      String? computedDetails;
      switch (i) {
        case 9:
          computedDetails = jsonOutput;
          break;
        case 8:
          computedDetails = nonJsonOutput;
          break;
        case 7:
          details = null;
          break;
        case 5:
          kind = 'stdout';
          details = ansiCodesOutput();
          break;
        default:
          break;
      }

      final detailsComputer = computedDetails == null
          ? null
          : () => Future.delayed(
                const Duration(seconds: 1),
                () => computedDetails!,
              );
      return LogData(kind, details, i, detailsComputer: detailsComputer);
    }

    final fakeLogData = List<LogData>.generate(totalLogs, generate);

    Future<void> pumpLoggingScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const LoggingScreenBody(),
          logging: mockLoggingController,
        ),
      );
    }

    setUp(() {
      mockLoggingController = MockLoggingController();
      when(mockLoggingController.data).thenReturn([]);
      when(mockLoggingController.search).thenReturn('');
      when(mockLoggingController.searchMatches)
          .thenReturn(ValueNotifier<List<LogData>>([]));
      when(mockLoggingController.searchInProgressNotifier)
          .thenReturn(ValueNotifier<bool>(false));
      when(mockLoggingController.matchIndex).thenReturn(ValueNotifier<int>(0));
      when(mockLoggingController.filteredData)
          .thenReturn(ListValueNotifier<LogData>([]));

      fakeServiceConnection = FakeServiceConnectionManager();
      final app = fakeServiceConnection.serviceManager.connectedApp!;
      when(app.isFlutterWebAppNow).thenReturn(false);
      when(app.isProfileBuildNow).thenReturn(false);
      // TODO(polinach): when we start supporting browser tests, uncomment
      // and fix the mock configuration.
      // See https://github.com/flutter/devtools/issues/3616.
      // when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
      //     .thenReturn(ValueNotifier<int>(0));
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      when(mockLoggingController.data).thenReturn(fakeLogData);
      when(mockLoggingController.filteredData)
          .thenReturn(ListValueNotifier<LogData>(fakeLogData));
    });

    testWidgetsWithWindowSize(
      'can process Ansi codes',
      windowSize,
      (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(fakeLogData[5])));
        await tester.pumpAndSettle();

        // Entry in tree.
        expect(
          find.richText('Ansi color codes processed for log 5'),
          findsOneWidget,
          reason: 'Processed text without ansi codes should exist in logs and '
              'details sections.',
        );

        // Entry in details panel.
        final finder =
            find.selectableText('Ansi color codes processed for log 5');

        expect(
          find.richText('Ansi color codes processed for log 5'),
          findsOneWidget,
          reason: 'Processed text without ansi codes should exist in logs and '
              'details sections.',
        );

        finder.evaluate().forEach((element) {
          final richText = element.widget as RichText;
          final textSpan = richText.text as TextSpan;
          final secondSpan = textSpan.children![1] as TextSpan;
          expect(
            secondSpan.text,
            'log 5',
            reason: 'Text with ansi code should be in separate span',
          );
          expect(
            secondSpan.style!.backgroundColor,
            const Color.fromRGBO(215, 95, 135, 1),
          );
        });
      },
    );
  });

  group('Debugger Screen', () {
    late FakeServiceConnectionManager fakeServiceConnection;
    late MockDebuggerController debuggerController;

    const windowSize = Size(4000.0, 4000.0);

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

    String ansiCodesOutput() {
      final sb = StringBuffer();
      sb.write('Ansi color codes processed for ');
      final pen = AnsiPen()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
      sb.write(pen('console'));
      return sb.toString();
    }

    setUp(() {
      // TODO(polinach): remove unnecessary setup steps after fixing
      // https://github.com/flutter/devtools/issues/3616.
      fakeServiceConnection = FakeServiceConnectionManager();
      final app = fakeServiceConnection.serviceManager.connectedApp!;
      when(app.isProfileBuildNow).thenReturn(false);
      when(app.isDartWebAppNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      fakeServiceConnection.consoleService.ensureServiceInitialized();

      // TODO(polinach): when we start supporting browser tests, uncomment
      // and fix the mock configuration.
      // See https://github.com/flutter/devtools/issues/3616.
      // when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
      //     .thenReturn(ValueNotifier<int>(0));

      debuggerController = createMockDebuggerControllerWithDefaults();
    });

    testWidgetsWithWindowSize(
      'Console area shows processed ansi text',
      windowSize,
      (WidgetTester tester) async {
        serviceConnection.consoleService.appendStdio(ansiCodesOutput());

        await pumpConsole(tester, debuggerController);

        final finder =
            find.selectableText('Ansi color codes processed for console');
        expect(finder, findsOneWidget);
        finder.evaluate().forEach((element) {
          final selectableText = element.widget as SelectableText;
          final textSpan = selectableText.textSpan!;
          final secondSpan = textSpan.children![1] as TextSpan;
          expect(
            secondSpan.text,
            'console',
            reason: 'Text with ansi code should be in separate span',
          );
          expect(
            secondSpan.style!.backgroundColor,
            const Color.fromRGBO(215, 95, 135, 1),
          );
        });
      },
    );
  });
}
