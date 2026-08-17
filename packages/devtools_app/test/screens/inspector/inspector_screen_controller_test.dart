// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ServiceConnectionManager serviceConnectionManager;
  late InspectorScreenController controller;

  setUp(() {
    serviceConnectionManager = ServiceConnectionManager();
    setGlobal(ServiceConnectionManager, serviceConnectionManager);
    controller = InspectorScreenController();
    // Mirror the badge-ownership registration performed in [init] without
    // constructing the full Inspector tree controllers.
    serviceConnection.errorBadgeManager.manageErrorCount(InspectorScreen.id);
  });

  int unreadBadgeCount() => serviceConnection.errorBadgeManager
      .errorCountNotifier(InspectorScreen.id)
      .value;

  test('appendError stores the error and increments the badge', () {
    controller.appendError(InspectableWidgetError('Overflow', 'ref-1'));

    expect(controller.inspectorErrors.value.length, equals(1));
    expect(controller.inspectorErrors.value['ref-1']!.errorMessage, 'Overflow');
    expect(unreadBadgeCount(), equals(1));
  });

  test('appendError does not double-count the same error id', () {
    controller.appendError(InspectableWidgetError('Overflow', 'ref-1'));
    controller.appendError(InspectableWidgetError('Overflow again', 'ref-1'));

    expect(controller.inspectorErrors.value.length, equals(1));
    expect(unreadBadgeCount(), equals(1));
  });

  test('markErrorAsRead decrements the badge', () {
    final error = InspectableWidgetError('Overflow', 'ref-1');
    controller.appendError(error);
    controller.markErrorAsRead(error);

    expect(controller.inspectorErrors.value['ref-1']!.read, isTrue);
    expect(unreadBadgeCount(), equals(0));
  });

  test('clearErrors resets errors and badge', () {
    controller.appendError(InspectableWidgetError('Overflow', 'ref-1'));
    controller.appendError(InspectableWidgetError('Null check', 'ref-2'));
    expect(unreadBadgeCount(), equals(2));

    controller.clearErrors();

    expect(controller.inspectorErrors.value, isEmpty);
    expect(unreadBadgeCount(), equals(0));
  });

  test(
    'scaffold-style clearErrorCount does not drop inspector unread badge',
    () {
      controller.appendError(InspectableWidgetError('Overflow', 'ref-1'));
      expect(unreadBadgeCount(), equals(1));

      // Simulates DevToolsScaffold clearing the badge on tab navigation.
      serviceConnection.errorBadgeManager.clearErrorCount(InspectorScreen.id);

      expect(unreadBadgeCount(), equals(1));
      expect(controller.inspectorErrors.value.length, equals(1));
    },
  );
}
