// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/flutter/import_export/import_export.dart';
import 'package:test/test.dart';

import 'flutter/wrappers.dart';

void main() async {
  group('ImportControllerTest', () {
    ImportController importController;
    TestNotifications notifications;
    setUp(() {
      notifications = TestNotifications();
      importController = ImportController(notifications, (_) {});
    });

    test('importData pushes proper notifications', () {
      expect(notifications.messages, isEmpty);
      importController.importData(nonDevToolsFileJson);
      expect(notifications.messages.length, equals(1));
      expect(notifications.messages, contains(nonDevToolsFileMessage));

      importController.importData(unsupportedDevToolsFileJson);
      expect(notifications.messages.length, equals(2));
      expect(
        notifications.messages,
        contains(attemptingToImportMessage('info')),
      );
    });
  });
}

final nonDevToolsFileJson = <String, dynamic>{};
final unsupportedDevToolsFileJson = <String, dynamic>{
  'dartDevToolsScreen': 'info',
};
final emptyTimelineJson = <String, dynamic>{
  'dartDevToolsScreen': 'timeline',
};
