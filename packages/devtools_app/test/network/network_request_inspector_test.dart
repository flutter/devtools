// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_infra/test_data/network.dart';
import '../test_infra/test_utils/test_utils.dart';

void main() {
  group('NetworkRequestInspector', () {
    late NetworkController controller;
    late FakeServiceManager fakeServiceManager;
    final HttpProfileRequest? httpRequest =
        HttpProfileRequest.parse(httpPostJson);
    String _clipboardContents = '';

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      _clipboardContents = '';
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          httpProfile: HttpProfile(
            requests: [
              httpRequest!,
            ],
            timestamp: 0,
          ),
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(NotificationService, NotificationService());
      controller = NetworkController();
      setupClipboardCopyListener(
        clipboardContentsCallback: (contents) {
          _clipboardContents = contents ?? '';
        },
      );
    });

    testWidgets('copy response body', (tester) async {
      final requestsNotifier = controller.requests;

      await controller.startRecording();

      await tester.pumpWidget(
        wrapWithControllers(
          NetworkRequestInspector(controller),
          debugger: createMockDebuggerControllerWithDefaults(),
        ),
      );

      // Load the network request.
      await controller.networkService.refreshNetworkData();
      expect(requestsNotifier.value.requests.length, equals(1));

      // Select the request in the network request list.
      final networkRequest = requestsNotifier.value.requests.first;
      controller.selectRequest(networkRequest);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();

      // Tap the responseBody copy button.
      expect(_clipboardContents, isEmpty);
      await tester.tap(find.byType(CopyToClipboardControl));
      final expectedResponseBody =
          jsonDecode(utf8.decode(httpRequest!.responseBody!.toList()));

      // Check that the contents were copied to clipboard.
      expect(_clipboardContents, isNotEmpty);
      expect(
        jsonDecode(_clipboardContents),
        equals(expectedResponseBody),
      );

      controller.stopRecording();

      // pumpAndSettle so residual http timers can clear.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  });
}
