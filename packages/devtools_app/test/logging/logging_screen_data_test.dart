// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:ansicolor/ansicolor.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/logging/_log_details.dart';
import 'package:devtools_app/src/screens/logging/_logs_table.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockLoggingController mockLoggingController;
  const windowSize = Size(1000.0, 1000.0);
  final fakeServiceConnection = FakeServiceConnectionManager();

  Future<void> pumpLoggingScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const LoggingScreenBody(),
        logging: mockLoggingController,
      ),
    );
  }

  setUp(() {
    mockLoggingController =
        createMockLoggingControllerWithDefaults(data: fakeLogData);

    when(fakeServiceConnection.serviceManager.connectedApp!.isFlutterWebAppNow)
        .thenReturn(false);
    when(fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow)
        .thenReturn(false);
    when(fakeServiceConnection.errorBadgeManager.errorCountNotifier('logging'))
        .thenReturn(ValueNotifier<int>(0));
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(NotificationService, NotificationService());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, IdeTheme());
  });

  testWidgetsWithWindowSize(
    'shows log items',
    windowSize,
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
    },
  );

  testWidgetsWithWindowSize(
    'can show non-computing log data',
    windowSize,
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
    },
  );

  testWidgetsWithWindowSize(
    'can show null log data',
    windowSize,
    (WidgetTester tester) async {
      await pumpLoggingScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(fakeLogData[7])));
      await tester.pumpAndSettle();
    },
  );

  testWidgetsWithWindowSize(
    'search field can enter text',
    windowSize,
    (WidgetTester tester) async {
      await pumpLoggingScreen(tester);
      verifyNever(mockLoggingController.clear());

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final TextField textField = tester.widget(textFieldFinder) as TextField;
      expect(textField.enabled, isTrue);
      await tester.enterText(find.byType(TextField), 'abc');
    },
  );

  testWidgetsWithWindowSize(
    'Copy to clipboard button enables/disables correctly',
    windowSize,
    (WidgetTester tester) async {
      await pumpLoggingScreen(tester);

      // Locates the copy to clipboard button's IconButton.
      ToolbarAction copyButton() => find
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
    },
  );

  testWidgetsWithWindowSize(
    'can compute details of non-json log data',
    windowSize,
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
    },
  );

  testWidgetsWithWindowSize(
    'can show details of json log data',
    windowSize,
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
    },
  );
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
