// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('chrome')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/console/widgets/console_pane.dart';
import 'package:devtools_app/src/shared/primitives/ansi_utils.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/ansi.dart';

void main() {
  group('ansi_up', () {
    test('test standard colors', () {
      final ansi = AnsiWriter();
      final sb = StringBuffer();
      // Test the 16 color defaults.
      for (int c = 0; c < 16; c++) {
        ansi
          ..reset()
          ..white(bold: true)
          ..xterm(c, bg: true);
        sb.write(ansi.write('$c '));
        ansi
          ..reset()
          ..xterm(c);
        sb.write(ansi.write(' $c '));
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
            ansi
              ..reset()
              ..rgb(r: r / 5, g: g / 5, b: b / 5, bg: true)
              ..white(bold: true);
            sb.write(ansi.write(' $c '));
            ansi
              ..reset()
              ..rgb(r: r / 5, g: g / 5, b: b / 5);
            sb.write(ansi.write(' $c '));
          }
          sb.writeln();
        }
      }

      for (int c = 0; c < 24; c++) {
        if (0 == c % 8) {
          sb.writeln();
        }
        ansi
          ..reset()
          ..gray(level: c / 23, bg: true)
          ..white(bold: true);
        sb.write(ansi.write(' ${c + 232} '));
        ansi
          ..reset()
          ..gray(level: c / 23);
        sb.write(ansi.write(' ${c + 232} '));
      }

      final output = StringBuffer();
      final ansiParser = AnsiParser(sb.toString());
      for (final entry in ansiParser.parse()) {
        if (entry.hasStyling) {
          output.write('<style ${entry.describeStyle}>${entry.text}</style>');
        } else {
          output.write(entry.text);
        }
      }
      expect(
        output.toString(),
        equals(
          '<style background #000000, color #ffffff>0 </style><style color #000000> 0 </style><style background #bb0000, color #ffffff>1 </style><style color #bb0000> 1 </style><style background #000000, color #ffffff>2 </style><style color #000000> 2 </style><style background #bb0000, color #ffffff>3 </style><style color #bb0000> 3 </style><style background #00bbbb, color #ffffff>4 </style><style color #00bbbb> 4 </style><style background #bbbbbb, color #ffffff>5 </style><style color #bbbbbb> 5 </style><style background #00bbbb, color #ffffff>6 </style><style color #00bbbb> 6 </style><style background #ffffff, color #ffffff>7 </style><style color #ffffff> 7 </style>\n'
          '<style background #555555, color #ffffff>8 </style><style color #555555> 8 </style><style background #ff5555, color #ffffff>9 </style><style color #ff5555> 9 </style><style background #000000, color #ffffff>10 </style><style color #000000> 10 </style><style background #ff5555, color #ffffff>11 </style><style color #ff5555> 11 </style><style background #55ffff, color #ffffff>12 </style><style color #55ffff> 12 </style><style background #ffffff, color #ffffff>13 </style><style color #ffffff> 13 </style><style background #55ffff, color #ffffff>14 </style><style color #55ffff> 14 </style><style background #ffffff, color #ffffff>15 </style><style color #ffffff> 15 </style>\n'
          '\n'
          '<style background #000000, color #ffffff> 16 </style><style color #000000> 16 </style><style background #00afaf, color #ffffff> 19 </style><style color #00afaf> 19 </style>\n'
          '<style background #000000, color #ffffff> 34 </style><style color #000000> 34 </style><style background #00afaf, color #ffffff> 37 </style><style color #00afaf> 37 </style>\n'
          '\n'
          '<style background #af0000, color #ffffff> 124 </style><style color #af0000> 124 </style><style background #afafaf, color #ffffff> 127 </style><style color #afafaf> 127 </style>\n'
          '<style background #af0000, color #ffffff> 142 </style><style color #af0000> 142 </style><style background #afafaf, color #ffffff> 145 </style><style color #afafaf> 145 </style>\n'
          '\n'
          '<style background #080808, color #ffffff> 232 </style><style color #080808> 232 </style><style background #121212, color #ffffff> 233 </style><style color #121212> 233 </style><style background #1c1c1c, color #ffffff> 234 </style><style color #1c1c1c> 234 </style><style background #262626, color #ffffff> 235 </style><style color #262626> 235 </style><style background #303030, color #ffffff> 236 </style><style color #303030> 236 </style><style background #3a3a3a, color #ffffff> 237 </style><style color #3a3a3a> 237 </style><style background #444444, color #ffffff> 238 </style><style color #444444> 238 </style><style background #4e4e4e, color #ffffff> 239 </style><style color #4e4e4e> 239 </style>\n'
          '<style background #585858, color #ffffff> 240 </style><style color #585858> 240 </style><style background #626262, color #ffffff> 241 </style><style color #626262> 241 </style><style background #6c6c6c, color #ffffff> 242 </style><style color #6c6c6c> 242 </style><style background #767676, color #ffffff> 243 </style><style color #767676> 243 </style><style background #808080, color #ffffff> 244 </style><style color #808080> 244 </style><style background #8a8a8a, color #ffffff> 245 </style><style color #8a8a8a> 245 </style><style background #949494, color #ffffff> 246 </style><style color #949494> 246 </style><style background #9e9e9e, color #ffffff> 247 </style><style color #9e9e9e> 247 </style>\n'
          '<style background #a8a8a8, color #ffffff> 248 </style><style color #a8a8a8> 248 </style><style background #b2b2b2, color #ffffff> 249 </style><style color #b2b2b2> 249 </style><style background #bcbcbc, color #ffffff> 250 </style><style color #bcbcbc> 250 </style><style background #c6c6c6, color #ffffff> 251 </style><style color #c6c6c6> 251 </style><style background #d0d0d0, color #ffffff> 252 </style><style color #d0d0d0> 252 </style><style background #dadada, color #ffffff> 253 </style><style color #dadada> 253 </style><style background #e4e4e4, color #ffffff> 254 </style><style color #e4e4e4> 254 </style><style background #eeeeee, color #ffffff> 255 </style><style color #eeeeee> 255 </style>',
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
      final ansi = AnsiWriter()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
      sb.write(ansi.write('log 5'));
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

      final detailsComputer =
          computedDetails == null
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
      when(
        mockLoggingController.searchMatches,
      ).thenReturn(ValueNotifier<List<LogData>>([]));
      when(
        mockLoggingController.searchInProgressNotifier,
      ).thenReturn(ValueNotifier<bool>(false));
      when(mockLoggingController.matchIndex).thenReturn(ValueNotifier<int>(0));
      when(
        mockLoggingController.filteredData,
      ).thenReturn(ListValueNotifier<LogData>([]));

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
      when(
        mockLoggingController.filteredData,
      ).thenReturn(ListValueNotifier<LogData>(fakeLogData));
    });

    testWidgetsWithWindowSize('can process Ansi codes', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpLoggingScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(fakeLogData[5])));
      await tester.pumpAndSettle();

      // Entry in tree.
      expect(
        find.richText('Ansi color codes processed for log 5'),
        findsOneWidget,
        reason:
            'Processed text without ansi codes should exist in logs and '
            'details sections.',
      );

      // Entry in details panel.
      final finder = find.selectableText(
        'Ansi color codes processed for log 5',
      );

      expect(
        find.richText('Ansi color codes processed for log 5'),
        findsOneWidget,
        reason:
            'Processed text without ansi codes should exist in logs and '
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
    });
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
      final ansi = AnsiWriter()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
      sb.write(ansi.write('console'));
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

        final finder = find.selectableText(
          'Ansi color codes processed for console',
        );
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
