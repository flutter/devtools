// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/device_dialog.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/service_registrations.dart' as registrations;
import 'package:devtools_app/src/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import '../support/utils.dart';
import 'wrappers.dart';

void main() {
  FakeServiceManager fakeServiceManager;

  group('DeviceDialog', () {
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
      when(fakeServiceManager.vm.version).thenReturn('1.9.1');
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isRunningOnDartVM).thenReturn(true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    }

    DeviceDialog deviceDialog;

    setUp(() {
      initServiceManager();
    });

    testWidgets('builds dialog dart web', (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isRunningOnDartVM).thenReturn(false);

      deviceDialog = DeviceDialog(
        connectedApp: fakeServiceManager.connectedApp,
        flutterVersion: null,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(findSubstring(deviceDialog, 'Dart Version'), findsOneWidget);
      expect(findSubstring(deviceDialog, 'Flutter Version'), findsNothing);
    });

    testWidgetsWithWindowSize(
        'builds dialog flutter', const Size(1000.0, 1000.0),
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isRunningOnDartVM).thenReturn(true);
      mockIsFlutterApp(fakeServiceManager.connectedApp);
      final flutterVersion = FlutterVersion.parse(
          (await fakeServiceManager.getFlutterVersion()).json);

      deviceDialog = DeviceDialog(
        connectedApp: fakeServiceManager.connectedApp,
        flutterVersion: flutterVersion,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(findSubstring(deviceDialog, 'Dart Version'), findsOneWidget);
      expect(findSubstring(deviceDialog, 'Flutter Version'), findsOneWidget);
    });
  });

  group('VMFlagsDialog', () {
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
      when(fakeServiceManager.vm.version).thenReturn('1.9.1');
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isRunningOnDartVM).thenReturn(true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    }

    VMFlagsDialog vmFlagsDialog;

    setUp(() {
      initServiceManager();

      vmFlagsDialog = VMFlagsDialog();
    });

    testWidgets('builds dialog', (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isRunningOnDartVM).thenReturn(true);
      mockIsFlutterApp(fakeServiceManager.connectedApp);

      await tester.pumpWidget(wrap(vmFlagsDialog));
      expect(find.text('VM Flags'), findsOneWidget);

      expect(findSubstring(vmFlagsDialog, 'flag 1 name'), findsOneWidget);
      expect(findSubstring(vmFlagsDialog, 'flag 1 comment'), findsOneWidget);
    });
  });
}
