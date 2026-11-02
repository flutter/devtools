// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Filename is sortable by time', () {
    final dates = [
      DateTime(1901, 2, 3, 4, 5, 6, 7),
      DateTime(1902, 1, 3, 4, 5, 6, 7),
      DateTime(1901, 10, 4, 4, 5, 6, 7),
      DateTime(1901, 20, 3, 4, 5, 6, 7),
      DateTime(1901, 20, 4, 2, 5, 6, 7),
      DateTime(1901, 10, 20, 4, 5, 6, 7),
      DateTime(1901, 10, 20, 4, 5, 6, 10),
    ];

    final sortedByTime = dates.sorted().map(
      (t) =>
          ExportController.generateFileName(time: t, type: ExportFileType.json),
    );

    final sortedByFileName = dates
        .map(
          (t) => ExportController.generateFileName(
            time: t,
            type: ExportFileType.json,
          ),
        )
        .sorted();

    expect(sortedByTime, sortedByFileName);
  });

  test('Filename hours are 0 to 23', () {
    final filename = ExportController.generateFileName(
      time: DateTime(1901, 2, 3, 14, 5, 6, 7),
      type: ExportFileType.json,
    );

    expect(filename, 'dart_devtools_1901-02-03_14:05:06.007.json');
  });

  group('ImportControllerTest', () {
    late ImportController importController;
    late NotificationService notifications;

    setUp(() {
      notifications = NotificationService();
      importController = ImportController((_) {});
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(NotificationService, notifications);
    });

    test('importData pushes proper notifications', () async {
      expect(notifications.activeMessages, isEmpty);
      importController.importData(nonDevToolsFileJson);
      expect(notifications.activeMessages.length, equals(1));
      expect(
        notifications.activeMessages.first.text,
        equals(nonDevToolsFileMessage),
      );

      await Future.delayed(
        const Duration(milliseconds: ImportController.repeatImportTimeBufferMs),
      );
      importController.importData(nonDevToolsFileJsonWithListData);
      expect(notifications.activeMessages.length, equals(2));
      expect(
        notifications.activeMessages[1].text,
        equals(nonDevToolsFileMessage),
      );

      await Future.delayed(
        const Duration(milliseconds: ImportController.repeatImportTimeBufferMs),
      );
      importController.importData(devToolsFileJson);
      expect(notifications.activeMessages.length, equals(3));
      expect(
        notifications.activeMessages[2].text,
        equals(attemptingToImportMessage('example')),
      );
    });

    test('importData pushes notification when activeScreenId is missing', () {
      importController.importData(devToolsFileJsonWithoutActiveScreenId);
      expect(notifications.activeMessages.length, equals(1));
      expect(
        notifications.activeMessages.first.text,
        equals(
          'The imported file is not a valid DevTools snapshot because it does '
          'not contain an activeScreenId field.',
        ),
      );
    });

    test(
      'importData pushes notification when activeScreenId is not a String',
      () {
        importController.importData(
          devToolsFileJsonWithNonStringActiveScreenId,
        );
        expect(notifications.activeMessages.length, equals(1));
        expect(
          notifications.activeMessages.first.text,
          equals(
            'The imported file is not a valid DevTools snapshot because it does '
            'not contain an activeScreenId field.',
          ),
        );
      },
    );

    test('importData pushes notification when screen data is missing', () {
      importController.importData(devToolsFileJsonWithoutScreenData);
      expect(notifications.activeMessages.length, equals(1));
      expect(
        notifications.activeMessages.first.text,
        equals(
          'The imported file does not contain data for screen \'example\'.',
        ),
      );
    });
  });
}

final nonDevToolsFileJson = DevToolsJsonFile(
  name: 'nonDevToolsFileJson',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(1000),
  data: <String, Object?>{},
);
final nonDevToolsFileJsonWithListData = DevToolsJsonFile(
  name: 'nonDevToolsFileJsonWithListData',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(1000),
  data: <Map<String, Object?>>[],
);
final devToolsFileJson = DevToolsJsonFile(
  name: 'devToolsFileJson',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(2000),
  data: <String, Object?>{
    'devToolsSnapshot': true,
    'activeScreenId': 'example',
    'example': {'title': 'example custom tools'},
  },
);
final devToolsFileJsonWithoutActiveScreenId = DevToolsJsonFile(
  name: 'devToolsFileJsonWithoutActiveScreenId',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(3000),
  data: <String, Object?>{
    'devToolsSnapshot': true,
    'example': {'title': 'example custom tools'},
  },
);
final devToolsFileJsonWithNonStringActiveScreenId = DevToolsJsonFile(
  name: 'devToolsFileJsonWithNonStringActiveScreenId',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(3500),
  data: <String, Object?>{
    'devToolsSnapshot': true,
    'activeScreenId': 12345,
    'example': {'title': 'example custom tools'},
  },
);
final devToolsFileJsonWithoutScreenData = DevToolsJsonFile(
  name: 'devToolsFileJsonWithoutScreenData',
  lastModifiedTime: DateTime.fromMicrosecondsSinceEpoch(4000),
  data: <String, Object?>{
    'devToolsSnapshot': true,
    'activeScreenId': 'example',
  },
);
