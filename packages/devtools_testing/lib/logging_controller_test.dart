// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member

// TODO(#1987): rewrite these tests for the flutter app.
/*
@TestOn('vm')
import 'dart:async';
import 'dart:ui';

import 'package:devtools_app/src/inspector/flutter_widget.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/table_data.dart';
import 'package:test/test.dart';

import 'support/fake_inspector_tree.dart';
import 'support/file_utils.dart';
import 'support/flutter_test_environment.dart';

/// If this test starts timing out it probably means the number of log messages
/// received has changed. Enable this flag to see what log messages are being
/// sent to debug the issue.
bool debugLogMessages = false;

/// Broadcast stream of log status messages received.
StreamController<String> logStatusController;

/// Broadcast stream of log data with gc events filtered out to keep tests predictable.
StreamController<LogData> logDataController;

// Broadcast stream with an event each time the details selection changes.
StreamController<void> detailsSelectionController;

List<LogData> unhandledLogData = [];

Stream<String> get logStatusStream => logStatusController.stream;

Stream<LogData> get logDataStream => logDataController.stream;

Stream<void> get detailsSelectionStream => detailsSelectionController.stream;

/// Current inspector tree displayed in the details view if any
FakeInspectorTree currentDetailsTree;

/// Current details text shown in the details view if any.
String currentDetailsText;

/// Returns a future after length new log data entries that are not GC events
/// have been added to the controller.
Future<List<LogData>> waitForNextLogData(int length) async {
  if (unhandledLogData.length < length) {
    await for (LogData value in logDataStream) {
      assert(value == unhandledLogData.last);
      if (unhandledLogData.length >= length) break;
    }
  }
  final ret = unhandledLogData;
  unhandledLogData = [];
  return ret;
}

Future<void> runLoggingControllerTests(FlutterTestEnvironment env) async {
  // Required as the logging view depends on the inspector which needs a version
  // of the widget catalog.
  Catalog.setCatalog(Catalog.decode(await widgetsJson()));

  final detailsValuesSet = <LogData>[];
  LoggingController loggingController;
  // Whether the log view is currently visible.
  bool visible;
  InspectorService inspectorService;

  env.afterNewSetup = () async {
    await ensureInspectorServiceDependencies();
  };

  env.afterEverySetup = () async {
    inspectorService = await InspectorService.create(env.service);
    visible = false;
    detailsValuesSet.clear();
    logStatusController = StreamController.broadcast();
    logDataController = StreamController.broadcast();
    detailsSelectionController = StreamController.broadcast();
    {
      final logDataItemsSeen = <LogData>{};
      loggingController = LoggingController(
        onLogCountStatusChanged: (logStatus) {
          logStatusController.add(logStatus);
          // Brute force approach to find all new log data entries.
          for (var row in loggingController.data) {
            if (logDataItemsSeen.add(row) && row.kind != 'gc') {
              if (debugLogMessages) {
                print(
                    'Received LogMessage(kind: ${row.kind}, summary: ${row.summary})');
              }
              logDataController.add(row);
              unhandledLogData.add(row);
            }
          }
        },
        isVisible: () => visible,
      );
      loggingController.detailsController = LoggingDetailsController(
        onShowInspector: () {},
        onShowDetails: ({String text, InspectorTreeController tree}) {
          currentDetailsTree = tree;
          currentDetailsText = text;
          detailsSelectionController.add(null);
        },
        createLoggingTree: ({VoidCallback onSelectionChange}) {
          return FakeInspectorTree()
            ..config = InspectorTreeConfig(
              summaryTree: false,
              treeType: FlutterTreeType.widget,
              onNodeAdded: (_, __) {},
              onSelectionChange: onSelectionChange,
              onExpand: (_) {},
              onHover: (_) {},
            );
        },
      );
    }
    loggingController.loggingTableModel = TableData();
    if (env.reuseTestEnvironment) {
      // TODO(jacobr): should we reset the service extension settings?
    }
    visible = true;
  };

  env.beforeEveryTearDown = () async {
    loggingController?.dispose();
    loggingController = null;
    inspectorService?.dispose();
    inspectorService = null;
  };

  group('logging controller tests', () {
    test('structured errors', () async {
      // Enable structured errors.
      await serviceManager.serviceExtensionManager.setServiceExtensionState(
        structuredErrors.extension,
        true,
        true,
      );

      // Clear the logging messages to avoid unpredictability about what point
      // the debugging tool was attached.
      loggingController.clear();
      unhandledLogData.clear();

      final evalOnDartLibrary = EvalOnDartLibrary(
        ['package:flutter_error_app/main.dart'],
        env.service,
      );

      await evalOnDartLibrary.eval(
        'print("Example message A',
        isAlive: null,
      );
      await evalOnDartLibrary.eval(
        'print("Example message B',
        isAlive: null,
      );

      var logEntries = await waitForNextLogData(2);
      expect(logEntries[0].kind, equals('stdout'));
      expect(logEntries[0].summary, equals('Example message A\n'));
      expect(logEntries[1].kind, equals('stdout'));
      expect(logEntries[1].summary, equals('Example message B\n'));

      await evalOnDartLibrary.eval(
        'navigateToScreen("Missing Material Example")',
        isAlive: null,
      );

      logEntries = await waitForNextLogData(3);
      expect(logEntries[0].kind, 'flutter.navigation');
      expect(logEntries[0].summary, equals('MaterialPageRoute<dynamic>(null)'));
      expect(logEntries[0].node, isNull);

      {
        final row = logEntries[1];
        expect(row.kind, 'flutter.error');
        // This error message will change when we apply further cleanup to the error messages.
        expect(row.summary, 'No Material widget found.');
        expect(row.node, isNotNull);
        final index = loggingController.loggingTableModel.data.indexOf(row);
        // The logging table may contain
        // other rows related to GC that we aren't interested in.
        expect(index, greaterThanOrEqualTo(2));
        expect(currentDetailsTree, isNull);
        final selectionChanged = detailsSelectionStream.first;
        // Trigger the details selection change.
        loggingController.loggingTableModel.setSelection(row, index);
        await selectionChanged;
        expect(currentDetailsText, isNull);
        expect(currentDetailsTree, isNotNull);
        expect(
          normalizeErrorText(currentDetailsTree.toStringDeep()),
          equalsGoldenIgnoringHashCodes(
            'logging_controller_material_error.txt',
          ),
        );
      }

      {
        final row = logEntries[2];
        expect(row.kind, 'flutter.error');
        expect(
            row.summary,
            matches(RegExp(
                r'A RenderFlex overflowed by \d+ pixels on the bottom.')));
        expect(row.node, isNotNull);
        final index = loggingController.loggingTableModel.data.indexOf(row);
        // The logging table may contain
        // other rows related to GC that we aren't interested in.
        expect(index, greaterThanOrEqualTo(4));
        final selectionChanged = detailsSelectionStream.first;
        // Trigger the details selection change.
        loggingController.loggingTableModel.setSelection(row, index);
        await selectionChanged;
        expect(currentDetailsText, isNull);
        expect(currentDetailsTree, isNotNull);
        expect(
          normalizeErrorText(currentDetailsTree.toStringDeep()),
          equalsGoldenIgnoringHashCodes(
            'logging_controller_overflow_error.txt',
          ),
        );
      }

      {
        final row = logEntries[0];
        expect(row.kind, 'flutter.navigation');
        final index = loggingController.loggingTableModel.data.indexOf(row);
        // The logging table may contain
        // other rows related to GC that we aren't interested in.
        expect(index, greaterThanOrEqualTo(0));
        final selectionChanged = detailsSelectionStream.first;
        // Trigger the details selection change.
        loggingController.loggingTableModel.setSelection(row, index);
        await selectionChanged;
        expect(
          normalizeErrorText(currentDetailsText),
          equalsGoldenIgnoringHashCodes(
            'logging_controller_navigation.txt',
          ),
        );

        expect(currentDetailsTree, isNull);
      }
      await env.tearDownEnvironment();
    });
  }, timeout: const Timeout.factor(8));
}

/// Normalize text in error messages that is likely unstable.
String normalizeErrorText(String message) {
  final lines = message.split('\n');
  return lines.map((line) {
    if (line.contains('file:///') || line.contains('package:')) {
      return '<STACK_TRACE_LINE>';
    }
    line = line.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#00000');
    return line.replaceAll(RegExp(r'\d+(\.\d+)?'), '<NUMBER>');
  }).join('\n');
}
*/
