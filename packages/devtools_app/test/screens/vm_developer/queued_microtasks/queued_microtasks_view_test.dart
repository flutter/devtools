// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/queued_microtasks/queued_microtasks_view.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../vm_developer_test_utils.dart';

void main() {
  group('QueuedMicrotasksViewBody', () {
    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          queuedMicrotasks: testQueuedMicrotasks,
        ),
      );

      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());
    });

    const windowSize = Size(2225.0, 1000.0);

    testWidgetsWithWindowSize('interactions work as intended', windowSize, (
      WidgetTester tester,
    ) async {
      // First, we verify that instructions explaining how to take a snapshot
      // are shown in the Queued Microtasks View in its initial state.

      await tester.pumpWidget(wrapSimple(QueuedMicrotasksViewBody()));

      expect(find.byType(RefreshQueuedMicrotasksButton), findsOneWidget);
      expect(find.byType(RefreshQueuedMicrotasksInstructions), findsOneWidget);

      // Then, we verify that after taking a snapshot, the user is instructed to
      // select a microtask ID to see information about the corresponding
      // microtask.

      await tester.tap(find.byType(RefreshQueuedMicrotasksButton));
      await tester.pumpAndSettle();

      final formattedTimestamp = QueuedMicrotasksViewBody.dateTimeFormat.format(
        DateTime.fromMicrosecondsSinceEpoch(testQueuedMicrotasks!.timestamp!),
      );
      expect(
        find.text('Viewing snapshot that was taken at $formattedTimestamp.'),
        findsOneWidget,
      );
      expect(find.byType(QueuedMicrotaskSelector), findsOneWidget);
      expect(
        find.text(
          'Select a microtask ID on the left to see information about the '
          'corresponding microtask.',
        ),
        findsOneWidget,
      );

      // Finally, we verify that after selecting a microtask ID, the user is
      // shown information about the corresponding microtask.

      await tester.tap(find.text(testMicrotask!.id.toString()));
      await tester.pumpAndSettle();

      expect(find.byType(MicrotaskStackTraceView), findsOneWidget);
    });
  });
}
