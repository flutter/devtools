// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late QueuedMicrotasksController controller;

  group('QueuedMicrotasksController', () {
    setUp(() {
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          queuedMicrotasks: testQueuedMicrotasks,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);

      controller = QueuedMicrotasksController();
    });

    test('refresh', () async {
      expect(controller.status.value, QueuedMicrotasksControllerStatus.empty);
      expect(controller.queuedMicrotasks.value, null);

      await controller.refresh();

      expect(controller.status.value, QueuedMicrotasksControllerStatus.ready);
      expect(controller.queuedMicrotasks.value, testQueuedMicrotasks);
    });
  });
}
