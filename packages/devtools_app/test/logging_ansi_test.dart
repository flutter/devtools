// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/logging/logging_screen.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/service_manager.dart';
import 'package:devtools_app/src/shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  MockLoggingController mockLoggingController;
  const windowSize = Size(1000.0, 1000.0);
  group('Logging Screen', () {
    FakeServiceManager fakeServiceManager;

    Future<void> pumpLoggingScreen(WidgetTester tester) async {
      await tester.pumpWidget(wrapWithControllers(
        const LoggingScreenBody(),
        logging: mockLoggingController,
      ));
    }

    setUp(() async {
      await ensureInspectorDependencies();
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

      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp.isFlutterWebAppNow)
          .thenReturn(false);
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier(any))
          .thenReturn(ValueNotifier<int>(0));
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    });

    group('with data', () {
      setUp(() {
        when(mockLoggingController.data).thenReturn(fakeLogData);
        when(mockLoggingController.filteredData)
            .thenReturn(ListValueNotifier<LogData>(fakeLogData));
      });

      testWidgetsWithWindowSize('can process Ansi codes', windowSize,
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
          final secondSpan = textSpan.children[1] as TextSpan;
          expect(
            secondSpan.text,
            'log 5',
            reason: 'Text with ansi code should be in separate span',
          );
          expect(
            secondSpan.style.backgroundColor,
            const Color.fromRGBO(215, 95, 135, 1),
          );
        });
      });
    });
  });
}

const totalLogs = 10;

final fakeLogData = List<LogData>.generate(totalLogs, _generate);

LogData _generate(int i) {
  String details = 'log event $i';
  String kind = 'kind $i';
  String computedDetails;
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
      details = _ansiCodesOutput();
      break;
    default:
      break;
  }

  final detailsComputer = computedDetails == null
      ? null
      : () => Future.delayed(const Duration(seconds: 1), () => computedDetails);
  return LogData(kind, details, i, detailsComputer: detailsComputer);
}

const nonJsonOutput = 'Non-json details for log number 8';
const jsonOutput = '{\n"Details": "of log event 9",\n"logEvent": "9"\n}\n';

String _ansiCodesOutput() {
  final sb = StringBuffer();
  sb.write('Ansi color codes processed for ');
  final pen = AnsiPen()..rgb(r: 0.8, g: 0.3, b: 0.4, bg: true);
  sb.write(pen('log 5'));
  return sb.toString();
}
