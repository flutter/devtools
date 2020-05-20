// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/info/flutter/info_screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/service_registrations.dart' as registrations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  InfoScreen screen;
  FakeServiceManager fakeServiceManager;
  group('Info Screen', () {
    void initServiceManager({
      bool useFakeService = true,
      bool flutterVersionServiceAvailable = true,
    }) {
      final availableServices = [
        if (flutterVersionServiceAvailable)
          registrations.flutterVersion.service,
      ];
      fakeServiceManager = FakeServiceManager(
        useFakeService: useFakeService,
        availableServices: availableServices,
      );
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      mockIsFlutterApp(fakeServiceManager.connectedApp);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    }

    setUp(() {
      initServiceManager();
      screen = const InfoScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Info'), findsOneWidget);
    });

    testWidgets('builds disabled message when disabled for web app',
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(true);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(InfoScreenBody), findsNothing);
      expect(find.byType(DisabledForWebAppMessage), findsOneWidget);
    });

    testWidgets('builds with version and flags data',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      await tester.pumpAndSettle();
      expect(find.byKey(InfoScreen.flutterVersionKey), findsOneWidget);
      expect(find.byKey(InfoScreen.flagListKey), findsOneWidget);
    });

    testWidgets('builds with no data', (WidgetTester tester) async {
      initServiceManager(
        useFakeService: false,
        flutterVersionServiceAvailable: false,
      );
      when(serviceManager.service.getFlagList()).thenAnswer((_) => null);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(InfoScreenBody), findsOneWidget);
      expect(find.byKey(InfoScreen.flutterVersionKey), findsNothing);
      expect(find.byKey(InfoScreen.flagListKey), findsNothing);
    });
  });
}
