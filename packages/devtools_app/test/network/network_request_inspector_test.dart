import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../fixtures/riverpod_app/lib/tester.dart';
import 'utils/network_test_utils.dart';

void main() {
  group('NetworkRequestInspector', () {
    late NetworkController controller;
    SocketProfile socketProfile;
    HttpProfile httpProfile;
    FakeServiceManager fakeServiceManager;

    setUpAll(() {
      setGlobal(IdeTheme, IdeTheme());
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
    });
    testWidgets('response', (tester) async {
      await controller.startRecording();
      final requestsNotifier = controller.requests;
      await controller.networkService.refreshNetworkData();
      final firstRequest = requestsNotifier.value.requests.first;
      print("FIRAST REQ ${firstRequest}");
      controller.selectRequest(firstRequest);
      final widget = NetworkRequestInspector(controller);

      final localizations = Localizations(
        locale: const Locale('en', 'US'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => widget,
              )
            ],
          ),
        ),
      );
      final media = MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
        child: localizations,
      );
      controller.stopRecording();
      await tester.pumpWidget(media);
    });
  });
}
