// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/logging/metadata.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/matchers/matchers.dart';

void main() {
  const windowSize = Size(1000.0, 1000.0);

  final testLogs = [
    // Log with kind stdout
    LogData('stdout', 'test details', 0),
    // Log with kind stderr
    LogData('stderr', 'test details', 1, isError: true),
    // Log with kind 'flutter.*'
    LogData('flutter.foo', 'test details', 2),
    // Log with Flutter frame time.
    LogData('flutter.frame', '{"elapsed":16249}', 3),
    // Log with Flutter error.
    LogData('flutter.error', 'some error', 4),
    // Log with level FINEST, and an isolateRef value.
    LogData(
      'my_app',
      'test details',
      5,
      level: Level.FINEST.value,
      isolateRef: IsolateRef(
        id: 'isolates/123',
        number: '1',
        name: 'main',
        isSystemIsolate: false,
      ),
    ),
    // Log with level FINER, and an isolateRef value.
    LogData(
      'my_app',
      'test details',
      6,
      level: Level.FINER.value,
      isolateRef: IsolateRef(
        id: 'isolates/123',
        number: '1',
        name: 'worker',
        isSystemIsolate: false,
      ),
    ),
    // Log with level FINE
    LogData('my_app', 'test details', 7, level: Level.FINE.value),
    // Log with level CONFIG
    LogData('my_app', 'test details', 8, level: Level.CONFIG.value),
    // Log with level INFO, and a custom zone.
    LogData(
      'my_app',
      'test details',
      9,
      level: Level.INFO.value,
      zone: (name: '_CustomZone', identityHashCode: 456),
    ),
    // Log with level WARNING, and the root zone.
    LogData(
      'my_app',
      'test details',
      10,
      level: Level.WARNING.value,
      zone: (name: '_RootZone', identityHashCode: 123),
    ),
    // Log with level SEVERE
    LogData('my_app', 'test details', 11, level: Level.SEVERE.value),
    // Log with level SHOUT
    LogData('my_app', 'test details', 12, level: Level.SHOUT.value),
  ];

  setUp(() {
    setGlobal(IdeTheme, getIdeTheme());
  });

  group('MetadataChips', () {
    const testKey = Key('test container');

    Future<void> pumpMetadataChips(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapSimple(
          Column(
            key: testKey,
            children:
                testLogs.map((log) {
                  return Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MetadataChips(data: log),
                    ),
                  );
                }).toList(),
          ),
        ),
      );
    }

    testWidgetsWithWindowSize('render for list of logs', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpMetadataChips(tester);
      await expectLater(
        find.byKey(testKey),
        matchesDevToolsGolden(
          '../../test_infra/goldens/logging/metadata_chips.png',
        ),
      );
    });
  });
}
