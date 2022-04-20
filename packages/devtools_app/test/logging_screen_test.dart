// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/logging/_log_details.dart';
import 'package:devtools_app/src/screens/logging/_logs_table.dart';
import 'package:devtools_app/src/screens/logging/_message_column.dart';
import 'package:devtools_app/src/screens/logging/logging_controller.dart';
import 'package:devtools_app/src/screens/logging/logging_screen.dart';
import 'package:devtools_app/src/service/service_extensions.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/ui/service_extension_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late LoggingScreen screen;
  MockLoggingController? mockLoggingController;
  const windowSize = Size(1000.0, 1000.0);

  group('Logging Screen', () {
    FakeServiceManager fakeServiceManager;

    Future<void> pumpLoggingScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const LoggingScreenBody(),
          logging: mockLoggingController,
        ),
      );
    }

    setUp(() async {
      await ensureInspectorDependencies();
      mockLoggingController = MockLoggingController();
      when(mockLoggingController!.data).thenReturn([]);
      when(mockLoggingController!.search).thenReturn('');
      when(mockLoggingController!.searchMatches)
          .thenReturn(ValueNotifier<List<LogData>>([]));
      when(mockLoggingController!.searchInProgressNotifier)
          .thenReturn(ValueNotifier<bool>(false));
      when(mockLoggingController!.matchIndex).thenReturn(ValueNotifier<int>(0));
      when(mockLoggingController!.filteredData)
          .thenReturn(ListValueNotifier<LogData>([]));

      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp!.isFlutterWebAppNow)
          .thenReturn(false);
      when(fakeServiceManager.connectedApp!.isProfileBuildNow)
          .thenReturn(false);
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier('logging'))
          .thenReturn(ValueNotifier<int>(0));
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());

      screen = const LoggingScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Logging'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds with no data', windowSize,
        (WidgetTester tester) async {
      await pumpLoggingScreen(tester);
      expect(find.byType(LoggingScreenBody), findsOneWidget);
      expect(find.byType(LogsTable), findsOneWidget);
      expect(find.byType(LogDetails), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(StructuredErrorsToggle), findsOneWidget);
    });

    testWidgetsWithWindowSize('can clear logs', windowSize,
        (WidgetTester tester) async {
      await pumpLoggingScreen(tester);
      verifyNever(mockLoggingController!.clear());
      await tester.tap(find.text('Clear'));
      verify(mockLoggingController!.clear()).called(1);
    });

    testWidgetsWithWindowSize(
        'search field is disabled with no data', windowSize,
        (WidgetTester tester) async {
      await pumpLoggingScreen(tester);
      verifyNever(mockLoggingController!.clear());

      final textFieldFinder = find.byKey(loggingSearchFieldKey);
      expect(textFieldFinder, findsOneWidget);
      final TextField textField = tester.widget(textFieldFinder) as TextField;
      expect(textField.enabled, isFalse);
    });

    testWidgetsWithWindowSize('can toggle structured errors', windowSize,
        (WidgetTester tester) async {
      final serviceManager = FakeServiceManager();
      when(serviceManager.connectedApp!.isFlutterWebAppNow).thenReturn(false);
      when(serviceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
      setGlobal(
        ServiceConnectionManager,
        serviceManager,
      );
      await pumpLoggingScreen(tester);
      Switch toggle = tester.widget(find.byType(Switch));
      expect(toggle.value, false);

      serviceManager.serviceExtensionManager
          .fakeServiceExtensionStateChanged(structuredErrors.extension, 'true');
      await tester.pumpAndSettle();
      toggle = tester.widget(find.byType(Switch));
      expect(toggle.value, true);

      // TODO(djshuckerow): Hook up fake extension state querying.
    });

    group('with data', () {
      setUp(() {
        when(mockLoggingController!.data).thenReturn(fakeLogData);
        when(mockLoggingController!.filteredData)
            .thenReturn(ListValueNotifier<LogData>(fakeLogData));
      });

      testWidgetsWithWindowSize('shows log items', windowSize,
          (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        await tester.pumpAndSettle();
        expect(find.byType(LogsTable), findsOneWidget);
        expect(
          find.byKey(ValueKey(fakeLogData.first)),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey(fakeLogData.last)),
          findsOneWidget,
        );
      });

      testWidgetsWithWindowSize('can show non-computing log data', windowSize,
          (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(fakeLogData[6])));
        await tester.pumpAndSettle();
        expect(
          find.selectableText('log event 6'),
          findsOneWidget,
          reason:
              'The log details should be visible both in the details section.',
        );
        expect(
          find.selectableText('log event 6'),
          findsOneWidget,
          reason: 'The log details should be visible both in the table.',
        );
      });

      testWidgetsWithWindowSize('can show null log data', windowSize,
          (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(fakeLogData[7])));
        await tester.pumpAndSettle();
      });

      testWidgetsWithWindowSize('search field can enter text', windowSize,
          (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        verifyNever(mockLoggingController!.clear());

        final textFieldFinder = find.byKey(loggingSearchFieldKey);
        expect(textFieldFinder, findsOneWidget);
        final TextField textField = tester.widget(textFieldFinder) as TextField;
        expect(textField.enabled, isTrue);
        await tester.enterText(find.byType(TextField), 'abc');
      });

      testWidgetsWithWindowSize(
          'Copy to clipboard button enables/disables correctly', windowSize,
          (WidgetTester tester) async {
        await pumpLoggingScreen(tester);

        // Locates the copy to clipboard button's IconButton.
        final copyButton = () => find
            .byKey(LogDetails.copyToClipboardButtonKey)
            .evaluate()
            .first
            .widget as ToolbarAction;

        expect(
          copyButton().onPressed,
          isNull,
          reason:
              'Copy to clipboard button should be disabled when no logs are selected',
        );

        await tester.tap(find.byKey(ValueKey(fakeLogData[5])));
        await tester.pumpAndSettle();

        expect(
          copyButton().onPressed,
          isNotNull,
          reason:
              'Copy to clipboard button should be enabled when a log with content is selected',
        );

        await tester.tap(find.byKey(ValueKey(fakeLogData[7])));
        await tester.pumpAndSettle();

        expect(
          copyButton().onPressed,
          isNull,
          reason:
              'Copy to clipboard button should be disabled when the log details are null',
        );
      });

      testWidgetsWithWindowSize(
          'can compute details of non-json log data', windowSize,
          (WidgetTester tester) async {
        const index = 8;
        final log = fakeLogData[index];

        await pumpLoggingScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(log)));
        await tester.pump();
        expect(
          find.selectableText(nonJsonOutput),
          findsNothing,
          reason:
              "The details of the log haven't computed yet, so they shouldn't "
              'be available.',
        );

        await tester.pumpAndSettle();
        expect(find.selectableText(nonJsonOutput), findsOneWidget);
      });

      testWidgetsWithWindowSize('can show details of json log data', windowSize,
          (WidgetTester tester) async {
        const index = 9;
        bool containsJson(Widget widget) {
          if (widget is! SelectableText) return false;
          final content = widget.data!.trim();
          return content.startsWith('{') && content.endsWith('}');
        }

        final findJson = find.descendant(
          of: find.byType(LogDetails),
          matching: find.byWidgetPredicate(containsJson),
        );

        await pumpLoggingScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(fakeLogData[index])));
        await tester.pump();

        expect(
          findJson,
          findsNothing,
          reason:
              "The details of the log haven't computed yet, so they shouldn't be available.",
        );

        await tester.pumpAndSettle();
        expect(findJson, findsOneWidget);
      });
    });

    group('MessageColumn', () {
      late MessageColumn column;

      setUp(() {
        column = MessageColumn();
      });

      test('compare sorts logs correctly', () {
        final a = LogData('test', 'Hello world', 1);
        final b = LogData('test', 'Test test test', 1);
        expect(column.compare(a, b), equals(-1));
      });

      test('compare special cases sorting for frame logs', () {
        final a = LogData('flutter.frame', '#9  3.6ms ', 1);
        final b = LogData('flutter.frame', '#10  3.6ms ', 1);
        expect(column.compare(a, b), equals(-1));

        // The number of spaces between the frame number and duration as well
        // as after the duration can be inconsistent. Verify that the regexp
        // still works.
        final c = LogData('flutter.frame', '#10 3.6ms', 1);
        final d = LogData('flutter.frame', '#9  3.6ms ', 1);
        expect(column.compare(c, d), equals(1));

        final e = LogData('flutter.frame', '#10  3.6ms ', 1);
        final f = LogData('flutter.frame', '#9foo  3.6ms ', 1);
        expect(column.compare(e, f), equals(-1));

        final l1 = LogData('flutter.frame', '#2  3.6ms ', 1);
        final l2 = LogData('flutter.frame', '#2NOTAMATCH  3.6ms ', 1);
        final l3 = LogData('flutter.frame', '#10  3.6ms ', 1);
        final l4 = LogData('flutter.frame', '#10NOTAMATCH  3.6ms ', 1);
        final l5 = LogData('flutter.frame', '#11  3.6ms ', 1);
        final l6 = LogData('flutter.frame', '#11NOTAMATCH  3.6ms ', 1);
        final list = [l1, l2, l3, l4, l5, l6];
        list.sort(column.compare);

        expect(list[0], equals(l1));
        expect(list[1], equals(l3));
        expect(list[2], equals(l5));
        expect(list[3], equals(l4));
        expect(list[4], equals(l6));
        expect(list[5], equals(l2));
      });
    });
  });
}

const totalLogs = 10;

final fakeLogData = List<LogData>.generate(totalLogs, _generate);

LogData _generate(int i) {
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
      details = _ansiCodesOutput();
      break;
    default:
      break;
  }

  final detailsComputer = computedDetails == null
      ? null
      : () =>
          Future.delayed(const Duration(seconds: 1), () => computedDetails!);
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
