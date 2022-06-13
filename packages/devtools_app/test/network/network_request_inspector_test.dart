import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/network/network_request_inspector.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../fixtures/riverpod_app/lib/tester.dart';
import 'network_profiler_test.dart';
import 'utils/network_test_utils.dart';

void main() {
  group('NetworkRequestInspector', () {
    late NetworkController controller;
    SocketProfile socketProfile;
    HttpProfile httpProfile;
    FakeServiceManager fakeServiceManager;
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
      // This intercepts the Clipboard.setData SystemChannel message,
      // and stores the contents that were (attempted) to be copied.
      SystemChannels.platform.setMockMethodCallHandler((MethodCall call) {
        switch (call.method) {
          case 'Clipboard.setData':
            _clipboardContents = call.arguments['text'];
            break;
          case 'Clipboard.getData':
            return Future.value(<String, dynamic>{});
          case 'Clipboard.hasStrings':
            return Future.value(<String, dynamic>{'value': true});
          default:
            break;
        }

        return Future.value(true);
      });
    });
    testWidgets('response', (tester) async {
      final requestsNotifier = controller.requests;
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
      final debuggerController = createMockDebuggerControllerWithDefaults();

      await controller.startRecording();
      await tester
          .pumpWidget(wrapWithControllers(media, debugger: debuggerController));
      await controller.networkService.refreshNetworkData();
      final firstRequest = requestsNotifier.value.requests[5];
      print("THE REQS: ${requestsNotifier.value.requests}");
      controller.selectRequest(firstRequest);
      await tester.pumpAndSettle();
      debugDumpApp();
      await tester.tap(find.text('Response'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CopyToClipboardControl));
      expect(_clipboardContents, isNotEmpty);
      expect(
        _clipboardContents,
        equals((firstRequest as DartIOHttpRequestData).responseBody),
      );
      controller.stopRecording();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  });
}

void buildNetworkRequestInspector() {}
