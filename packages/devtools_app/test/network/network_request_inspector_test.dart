// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/screens/network/network_controller.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../test_utils/test_utils.dart';
import 'utils/network_test_utils.dart';

void main() {
  group('NetworkRequestInspector', () {
    late NetworkController controller;
    late SocketProfile socketProfile;
    late HttpProfile httpProfile;
    late FakeServiceManager fakeServiceManager;
    late String _clipboardContents;

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      _clipboardContents = '';
      socketProfile = loadSocketProfile();
      httpProfile = loadHttpProfile();
      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          socketProfile: socketProfile,
          httpProfile: httpProfile,
        ),
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      controller = NetworkController();
      setupClipboardCopyListener(clipboardContentsCallback: (contents) {
        _clipboardContents = contents ?? '';
      });
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

      await controller.networkService.refreshNetworkData();
      final networkRequest = requestsNotifier.value.requests[5];

      controller.selectRequest(networkRequest);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();

      expect(_clipboardContents, isEmpty);
      await tester.tap(find.byType(CopyToClipboardControl));

      expect(_clipboardContents, isNotEmpty);
      expect(
        _clipboardContents,
        equals((networkRequest as DartIOHttpRequestData).responseBody),
      );

      controller.stopRecording();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  });
}
