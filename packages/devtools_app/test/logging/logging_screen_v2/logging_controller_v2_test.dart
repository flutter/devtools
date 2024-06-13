// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: unused_import

@TestOn('vm')
library;

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggingControllerV2', () {
    late LoggingControllerV2 controller;

    void addStdoutData(String message) {
      controller.log(
        LogDataV2(
          'stdout',
          jsonEncode({'kind': 'stdout', 'message': message}),
          0,
          summary: message,
        ),
      );
    }

    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(),
      );
      setGlobal(IdeTheme, getIdeTheme());
      setGlobal(MessageBus, MessageBus());
      setGlobal(GlobalKey<NavigatorState>, GlobalKey<NavigatorState>());
      TestWidgetsFlutterBinding.ensureInitialized();
      controller = LoggingControllerV2();
    });

    test('initial state', () {
      expect(controller.loggingModel.logCount, 0);
      expect(controller.loggingModel.filteredLogCount, 0);
      expect(controller.loggingModel.selectedLogCount, 0);
      expect(controller.activeFilter.value.isEmpty, isTrue);
    });

    test('receives data', () {
      expect(controller.loggingModel.logCount, 0);
      expect(controller.loggingModel.filteredLogCount, 0);
      expect(controller.loggingModel.selectedLogCount, 0);

      addStdoutData('Abc.');

      expect(controller.loggingModel.logCount, 1);
      expect(controller.loggingModel.filteredLogCount, 1);
      expect(controller.loggingModel.selectedLogCount, 0);

      expect(
        controller.loggingModel.filteredLogAt(0).summary,
        contains('Abc'),
      );
    });

    test('clear', () {
      addStdoutData('Abc.');

      expect(controller.loggingModel.logCount, 1);
      expect(controller.loggingModel.filteredLogCount, 1);

      controller.clear();

      expect(controller.loggingModel.logCount, 0);
      expect(controller.loggingModel.filteredLogCount, 0);
    });
  });

  group('LogData', () {
    test(
      'pretty prints when details are json, and returns its details otherwise.',
      () {
        final nonJson = LogData('some kind', 'Not json', 0);
        final json = LogData(
          'some kind',
          '{"firstValue": "value", "otherValue": "value2"}',
          1,
        );
        final nullDetails = LogData('some kind', null, 1);
        const prettyJson = '{\n'
            '  "firstValue": "value",\n'
            '  "otherValue": "value2"\n'
            '}';

        expect(json.prettyPrinted(), prettyJson);
        expect(nonJson.prettyPrinted(), 'Not json');
        expect(nullDetails.prettyPrinted(), null);
      },
    );
  });
}
