// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/network/flutter/network_screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  NetworkScreen screen;
  FakeServiceManager fakeServiceManager;

  group('NetworkScreen', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      screen = const NetworkScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Network'), findsOneWidget);
    });

    testWidgets('builds disabled message when disabled for web app',
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(true);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(NetworkScreenBody), findsNothing);
      expect(find.byType(DisabledForWebAppMessage), findsOneWidget);
    });
  });
}
