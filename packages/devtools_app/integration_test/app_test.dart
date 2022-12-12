// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/framework/landing_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utilities.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestApp testApp;

  setUpAll(() {
    print('========== setUpAll ================');
    testApp = TestApp.fromEnvironment();
    expect(testApp.vmServiceUri, isNotNull);
  });

  tearDown(() {
    print('========== tearDown ================');
  });

  testWidgets('Connect screen loads', (tester) async {
    print('========== begin connect screen loads test ================');
    await pumpDevTools(tester);
    expect(find.byType(LandingScreenBody), findsOneWidget);
    expect(find.text('No client connection'), findsOneWidget);

    print('========== end connect screen loads test ================');
  });

  // testWidgets('Connect screen loads 2', (tester) async {
  //   print('========== begin connect screen loads test ================');
  //   await pumpDevTools(tester);
  //   expect(find.byType(LandingScreenBody), findsOneWidget);
  //   expect(find.text('No client connection'), findsOneWidget);

  //   print('========== end connect screen loads test ================');
  // });

  // testWidgets('can connect to app', (tester) async {
  //   print('========== begin app connection test ================');
  //   await pumpDevTools(tester);
  //   await connectToTestApp(tester, testApp);
  //   expect(find.byType(LandingScreenBody), findsNothing);
  //   expect(find.text('No client connection'), findsNothing);
  //   print('========== end app connection test ================');

  //   // await binding.callbackManager.callback(params, testRunner)
  // });
}
