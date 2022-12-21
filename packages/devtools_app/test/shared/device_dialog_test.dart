// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/service/service_registrations.dart'
    as registrations;
import 'package:devtools_app/src/shared/device_dialog.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late FakeServiceManager fakeServiceManager;

  const windowSize = Size(2000.0, 1000.0);

  group('DeviceDialog', () {
    Future<void> initServiceManager({
      bool flutterVersionServiceAvailable = true,
    }) async {
      final availableServices = [
        if (flutterVersionServiceAvailable)
          registrations.flutterVersion.service,
      ];
      fakeServiceManager = FakeServiceManager(
        availableServices: availableServices,
      );
      when(fakeServiceManager.vm.version).thenReturn('1.9.1');
      when(fakeServiceManager.vm.targetCPU).thenReturn('x64');
      when(fakeServiceManager.vm.architectureBits).thenReturn(64);
      when(fakeServiceManager.vm.operatingSystem).thenReturn('android');
      final app = fakeServiceManager.connectedApp!;
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
    }

    DeviceDialog deviceDialog;

    setUp(() async {
      await initServiceManager();
    });

    testWidgetsWithWindowSize('builds dialog for dart web app', windowSize,
        (WidgetTester tester) async {
      final app = fakeServiceManager.connectedApp!;
      mockWebVm(fakeServiceManager.vm);
      mockConnectedApp(
        app,
        isFlutterApp: false,
        isProfileBuild: false,
        isWebApp: true,
      );

      deviceDialog = DeviceDialog(
        connectedApp: app,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(find.text('CPU / OS: '), findsOneWidget);
      expect(find.text('Web macos'), findsOneWidget);
      expect(find.text('Dart Version: '), findsOneWidget);
      expect(find.text('1.9.1'), findsOneWidget);
      expect(find.text('Flutter Version: '), findsNothing);
      expect(find.text('Framework / Engine: '), findsNothing);
      expect(find.text('Connected app type: '), findsOneWidget);
      expect(find.text('Dart web'), findsOneWidget);
      expect(find.text('VM Service Connection: '), findsOneWidget);
      expect(find.text('ws://127.0.0.1:56137/ISsyt6ki0no=/ws'), findsOneWidget);
      expect(find.byType(CopyToClipboardControl), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds dialog for dart CLI app', windowSize,
        (WidgetTester tester) async {
      final app = fakeServiceManager.connectedApp!;
      when(fakeServiceManager.vm.operatingSystem).thenReturn('macos');
      mockConnectedApp(
        app,
        isFlutterApp: false,
        isProfileBuild: false,
        isWebApp: false,
      );

      deviceDialog = DeviceDialog(
        connectedApp: app,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(find.text('CPU / OS: '), findsOneWidget);
      expect(find.text('x64 (64 bit) macos'), findsOneWidget);
      expect(find.text('Dart Version: '), findsOneWidget);
      expect(find.text('1.9.1'), findsOneWidget);
      expect(find.text('Flutter Version: '), findsNothing);
      expect(find.text('Framework / Engine: '), findsNothing);
      expect(find.text('Connected app type: '), findsOneWidget);
      expect(find.text('Dart CLI'), findsOneWidget);
      expect(find.text('VM Service Connection: '), findsOneWidget);
      expect(find.text('ws://127.0.0.1:56137/ISsyt6ki0no=/ws'), findsOneWidget);
      expect(find.byType(CopyToClipboardControl), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'builds dialog for flutter native app (debug)', windowSize,
        (WidgetTester tester) async {
      final app = fakeServiceManager.connectedApp!;
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );

      deviceDialog = DeviceDialog(
        connectedApp: app,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(find.text('CPU / OS: '), findsOneWidget);
      expect(find.text('x64 (64 bit) android'), findsOneWidget);
      expect(find.text('Dart Version: '), findsOneWidget);
      expect(find.text('1.9.1'), findsOneWidget);
      expect(find.text('Flutter Version: '), findsOneWidget);
      expect(find.text('2.10.0 / unknown'), findsOneWidget);
      expect(find.text('Framework / Engine: '), findsOneWidget);
      expect(find.text('74432fa91c / ae2222f47e'), findsOneWidget);
      expect(find.text('Connected app type: '), findsOneWidget);
      expect(find.text('Flutter native (debug build)'), findsOneWidget);
      expect(find.text('VM Service Connection: '), findsOneWidget);
      expect(find.text('ws://127.0.0.1:56137/ISsyt6ki0no=/ws'), findsOneWidget);
      expect(find.byType(CopyToClipboardControl), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'builds dialog for flutter native app (profile)', windowSize,
        (WidgetTester tester) async {
      final app = fakeServiceManager.connectedApp!;
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: false,
      );

      deviceDialog = DeviceDialog(
        connectedApp: app,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(find.text('CPU / OS: '), findsOneWidget);
      expect(find.text('Dart Version: '), findsOneWidget);
      expect(find.text('1.9.1'), findsOneWidget);
      expect(find.text('Flutter Version: '), findsOneWidget);
      expect(find.text('2.10.0 / unknown'), findsOneWidget);
      expect(find.text('Framework / Engine: '), findsOneWidget);
      expect(find.text('74432fa91c / ae2222f47e'), findsOneWidget);
      expect(find.text('Connected app type: '), findsOneWidget);
      expect(find.text('Flutter native (profile build)'), findsOneWidget);
      expect(find.text('VM Service Connection: '), findsOneWidget);
      expect(find.text('ws://127.0.0.1:56137/ISsyt6ki0no=/ws'), findsOneWidget);
      expect(find.byType(CopyToClipboardControl), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'builds dialog for flutter web app (debug)', windowSize,
        (WidgetTester tester) async {
      final app = fakeServiceManager.connectedApp!;
      mockWebVm(fakeServiceManager.vm);
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: true,
      );

      deviceDialog = DeviceDialog(
        connectedApp: app,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(find.text('CPU / OS: '), findsOneWidget);
      expect(find.text('Web macos'), findsOneWidget);
      expect(find.text('Dart Version: '), findsOneWidget);
      expect(find.text('1.9.1'), findsOneWidget);
      expect(find.text('Flutter Version: '), findsOneWidget);
      expect(find.text('2.10.0 / unknown'), findsOneWidget);
      expect(find.text('Framework / Engine: '), findsOneWidget);
      expect(find.text('74432fa91c / ae2222f47e'), findsOneWidget);
      expect(find.text('Connected app type: '), findsOneWidget);
      expect(find.text('Flutter web (debug build)'), findsOneWidget);
      expect(find.text('VM Service Connection: '), findsOneWidget);
      expect(find.text('ws://127.0.0.1:56137/ISsyt6ki0no=/ws'), findsOneWidget);
      expect(find.byType(CopyToClipboardControl), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'builds dialog for flutter web app (profile)', windowSize,
        (WidgetTester tester) async {
      final app = fakeServiceManager.connectedApp!;
      mockWebVm(fakeServiceManager.vm);
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: true,
      );

      deviceDialog = DeviceDialog(
        connectedApp: app,
      );

      await tester.pumpWidget(wrap(deviceDialog));
      expect(find.text('Device Info'), findsOneWidget);

      expect(find.text('CPU / OS: '), findsOneWidget);
      expect(find.text('Web macos'), findsOneWidget);
      expect(find.text('Dart Version: '), findsOneWidget);
      expect(find.text('1.9.1'), findsOneWidget);
      expect(find.text('Flutter Version: '), findsOneWidget);
      expect(find.text('2.10.0 / unknown'), findsOneWidget);
      expect(find.text('Framework / Engine: '), findsOneWidget);
      expect(find.text('74432fa91c / ae2222f47e'), findsOneWidget);
      expect(find.text('Connected app type: '), findsOneWidget);
      expect(find.text('Flutter web (profile build)'), findsOneWidget);
      expect(find.text('VM Service Connection: '), findsOneWidget);
      expect(find.text('ws://127.0.0.1:56137/ISsyt6ki0no=/ws'), findsOneWidget);
      expect(find.byType(CopyToClipboardControl), findsOneWidget);
    });
  });

  group('VMFlagsDialog', () {
    void initServiceManager({
      bool flutterVersionServiceAvailable = true,
    }) {
      final availableServices = [
        if (flutterVersionServiceAvailable)
          registrations.flutterVersion.service,
      ];
      fakeServiceManager = FakeServiceManager(
        availableServices: availableServices,
      );
      when(fakeServiceManager.vm.version).thenReturn('1.9.1');
      final app = fakeServiceManager.connectedApp!;
      when(app.isDartWebAppNow).thenReturn(false);
      when(app.isRunningOnDartVM).thenReturn(true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
    }

    late VMFlagsDialog vmFlagsDialog;

    setUp(() {
      initServiceManager();

      vmFlagsDialog = VMFlagsDialog();
    });

    testWidgets('builds dialog', (WidgetTester tester) async {
      mockConnectedApp(
        fakeServiceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );

      await tester.pumpWidget(wrap(vmFlagsDialog));
      expect(find.richText('VM Flags'), findsOneWidget);
      expect(find.richText('flag 1 name'), findsOneWidget);
      final RichText commentText = tester.firstWidget<RichText>(
        findSubstring(vmFlagsDialog, 'flag 1 comment'),
      );
      expect(commentText, isNotNull);
    });
  });
}
