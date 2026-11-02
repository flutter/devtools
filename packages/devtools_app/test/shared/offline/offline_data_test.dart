// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/config_specific/import_export/import_export.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestScreenController extends DevToolsScreenController
    with
        AutoDisposeControllerMixin,
        OfflineScreenControllerMixin<Map<String, Object?>> {
  Map<String, Object?>? loadedData;

  @override
  String get screenId => 'test_screen';

  Future<bool> initOfflineData(
    String screenId, {
    bool shouldLoad = true,
    bool throwOnLoad = false,
  }) {
    return maybeLoadOfflineData(
      screenId,
      createData: (json) {
        if (json.containsKey('throw')) {
          throw Exception('Corrupted data');
        }
        return json;
      },
      shouldLoad: (data) => shouldLoad && data.isNotEmpty,
      loadData: (data) {
        if (throwOnLoad) {
          throw Exception('Failed during loadData');
        }
        loadedData = data;
      },
    );
  }

  @override
  OfflineScreenData prepareOfflineScreenData() =>
      OfflineScreenData(screenId: 'test_screen', data: loadedData ?? {});
}

void main() {
  group('OfflineScreenControllerMixin', () {
    late _TestScreenController controller;
    late NotificationService notifications;

    setUp(() {
      notifications = NotificationService();
      setGlobal(NotificationService, notifications);
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      controller = _TestScreenController();
    });

    test('loads offline data when data is valid and non-empty', () async {
      offlineDataController
        ..startShowingOfflineData(offlineApp: MockConnectedApp())
        ..offlineDataJson = {
          DevToolsExportKeys.activeScreenId.name: 'test_screen',
          'test_screen': {'key': 'value'},
        };

      final result = await controller.initOfflineData('test_screen');
      expect(result, isTrue);
      expect(controller.loadedData, equals({'key': 'value'}));
      expect(notifications.activeMessages, isEmpty);
    });

    test('notifies when screen data is empty', () async {
      offlineDataController
        ..startShowingOfflineData(offlineApp: MockConnectedApp())
        ..offlineDataJson = {
          DevToolsExportKeys.activeScreenId.name: 'test_screen',
          'test_screen': <String, Object?>{},
        };

      final result = await controller.initOfflineData('test_screen');
      expect(result, isFalse);
      expect(controller.loadedData, isNull);
      expect(notifications.activeMessages.length, equals(1));
      expect(
        notifications.activeMessages.first.text,
        equals(
          'The imported file does not contain any data for screen \'test_screen\'.',
        ),
      );
    });

    test('notifies when shouldLoad returns false', () async {
      offlineDataController
        ..startShowingOfflineData(offlineApp: MockConnectedApp())
        ..offlineDataJson = {
          DevToolsExportKeys.activeScreenId.name: 'test_screen',
          'test_screen': {'key': 'value'},
        };

      final result = await controller.initOfflineData(
        'test_screen',
        shouldLoad: false,
      );
      expect(result, isFalse);
      expect(controller.loadedData, isNull);
      expect(notifications.activeMessages.length, equals(1));
      expect(
        notifications.activeMessages.first.text,
        equals(
          'The imported file does not contain any data for screen \'test_screen\'.',
        ),
      );
    });

    test('notifies when creating/loading data throws an error', () async {
      offlineDataController
        ..startShowingOfflineData(offlineApp: MockConnectedApp())
        ..offlineDataJson = {
          DevToolsExportKeys.activeScreenId.name: 'test_screen',
          'test_screen': {'throw': true},
        };

      final result = await controller.initOfflineData('test_screen');
      expect(result, isFalse);
      expect(controller.loadedData, isNull);
      expect(notifications.activeMessages.length, equals(1));
      expect(
        notifications.activeMessages.first.text,
        contains('Failed to load offline data for screen \'test_screen\':'),
      );
    });

    test(
      'resets loadingOfflineData and notifies when loadData throws',
      () async {
        offlineDataController
          ..startShowingOfflineData(offlineApp: MockConnectedApp())
          ..offlineDataJson = {
            DevToolsExportKeys.activeScreenId.name: 'test_screen',
            'test_screen': {'key': 'value'},
          };

        expect(controller.loadingOfflineData.value, isFalse);
        final result = await controller.initOfflineData(
          'test_screen',
          throwOnLoad: true,
        );
        expect(result, isFalse);
        expect(controller.loadingOfflineData.value, isFalse);
        expect(notifications.activeMessages.length, equals(1));
        expect(
          notifications.activeMessages.first.text,
          contains('Failed to load offline data for screen \'test_screen\':'),
        );
      },
    );

    test(
      'returns false without notifying if screen is not in offlineDataJson',
      () async {
        offlineDataController
          ..startShowingOfflineData(offlineApp: MockConnectedApp())
          ..offlineDataJson = {
            DevToolsExportKeys.activeScreenId.name: 'other_screen',
            'other_screen': {'key': 'value'},
          };

        final result = await controller.initOfflineData('test_screen');
        expect(result, isFalse);
        expect(controller.loadedData, isNull);
        expect(notifications.activeMessages, isEmpty);
      },
    );
  });
}
