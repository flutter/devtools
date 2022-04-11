// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  group('ImportControllerTest', () {
    late ImportController importController;
    late TestNotifications notifications;
    setUp(() {
      notifications = TestNotifications();
      importController = ImportController(notifications, (_) {});
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(ServiceConnectionManager, FakeServiceManager());
    });

    test('importData pushes proper notifications', () async {
      expect(notifications.messages, isEmpty);
      importController.importData(nonDevToolsFileJson);
      expect(notifications.messages.length, equals(1));
      expect(notifications.messages, contains(nonDevToolsFileMessage));

      await Future.delayed(
        const Duration(
          milliseconds: ImportController.repeatImportTimeBufferMs,
        ),
      );
      importController.importData(nonDevToolsFileJsonWithListData);
      expect(notifications.messages.length, equals(2));
      expect(notifications.messages, contains(nonDevToolsFileMessage));

      await Future.delayed(
        const Duration(
          milliseconds: ImportController.repeatImportTimeBufferMs,
        ),
      );
      importController.importData(devToolsFileJson);
      expect(notifications.messages.length, equals(3));
      expect(
        notifications.messages,
        contains(attemptingToImportMessage('example')),
      );
    });
  });
}

final nonDevToolsFileJson = DevToolsJsonFile(
  name: 'nonDevToolsFileJson',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(1000),
  data: <String, dynamic>{},
);
final nonDevToolsFileJsonWithListData = DevToolsJsonFile(
  name: 'nonDevToolsFileJsonWithListData',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(1000),
  data: <Map<String, dynamic>>[],
);
final devToolsFileJson = DevToolsJsonFile(
  name: 'devToolsFileJson',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(2000),
  data: <String, dynamic>{
    'devToolsSnapshot': true,
    'activeScreenId': 'example',
    'example': {'title': 'example custom tools'}
  },
);
