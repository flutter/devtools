// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:devtools_extensions/src/template/_simulated_devtools_environment/_simulated_devtools_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_web_plugins/url_strategy.dart';
// import 'package:foo_devtools_extension/src/foo_devtools_extension.dart';
import 'package:integration_test/integration_test.dart';

// To run this test:
// dart run integration_test/run_tests.dart dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/app_test.dart --dart-define=use_simulated_environment=true
//
// Or use flutter driver directly (you'll have to run chromedriver --port=4444 before for this to work):
// flutter drive --driver=test_driver/integration_test.dart --target=integration_test/simulated_environment_test.dart -d chrome --dart-define=use_simulated_environment=true

const shortPumpDuration = Duration(seconds: 1);
const safePumpDuration = Duration(seconds: 3);
const longPumpDuration = Duration(seconds: 6);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // setUpAll(() {
  //   // print('call use path url strategy');
  //   // usePathUrlStrategy();
  // });

  // tearDown(() async {
  //   print('in tear down');
  //   // ignore: avoid-dynamic, necessary here.
  //   // await (ui.PlatformDispatcher.instance.views.single as dynamic)
  //   // .resetHistory();
  // });

  testWidgets('end to end simulated environment', (tester) async {
    print('call use path url strategy');
    // usePathUrlStrategy();
    print('right before run app');
    // runApp(const FooDevToolsExtension());
    runApp(
      const DevToolsExtension(
        child: Center(child: Text('home')),
      ),
    );

    print('after run app');
    await tester.pump(longPumpDuration);
    print('after pump');
    // expect(find.byType(FooDevToolsExtension), findsOneWidget);
    // expect(find.byType(DevToolsExtension), findsOneWidget);
    // expect(find.byType(SimulatedDevToolsWrapper), findsOneWidget);
    print('after all expectations');
  });
}

  // final extensionView =
  //     tester.widget<EmbeddedExtensionView>(find.byType(EmbeddedExtensionView));
  // final controller = extensionView.controller
  //     as web_controller.EmbeddedExtensionControllerImpl;
  // bool onLoadCalled = false;
  // final subscription = controller.extensionIFrame.onLoad.listen((_) {
  //   onLoadCalled = true;
  // });
  // await tester.tap(forceReloadExtensionFinder);
  // await tester.pumpAndSettle(safePumpDuration);

  // expect(onLoadCalled, isTrue);
  // await subscription.cancel();