// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/ui/vm_flag_widgets.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;

  group('home screen with no app connection', () {
    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        fakeServiceConnection = FakeServiceConnectionManager(),
      );
      setGlobal(IdeTheme, IdeTheme());
      fakeServiceConnection.serviceManager.hasConnection = false;
    });

    testWidgetsWithWindowSize(
      'displays without error',
      const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
        // Build our app and trigger a frame.
        await tester.pumpWidget(wrap(const HomeScreenBody()));
        expect(find.byType(ConnectionSection), findsOneWidget);
        expect(find.byType(ConnectDialog), findsOneWidget);
        expect(find.byType(ConnectToNewAppButton), findsNothing);
        expect(find.byType(ViewVmFlagsButton), findsNothing);
        expect(find.byType(SampleDataDropDownButton), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'displays sample data picker as expected',
      const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
        // Build our app and trigger a frame.
        await tester.pumpWidget(
          wrap(
            HomeScreenBody(
              sampleData: [
                DevToolsJsonFile(
                  name: 'test-data',
                  lastModifiedTime: DateTime.now(),
                  data: <String, Object?>{},
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SampleDataDropDownButton), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<DevToolsJsonFile>));
        await tester.pumpAndSettle();

        expect(find.text('test-data'), findsOneWidget);
      },
    );
  });

  group('home screen with app connection', () {
    void initServiceManager() {
      fakeServiceConnection = FakeServiceConnectionManager();
      when(fakeServiceConnection.serviceManager.vm.version).thenReturn('1.9.1');
      when(fakeServiceConnection.serviceManager.vm.targetCPU).thenReturn('x64');
      when(fakeServiceConnection.serviceManager.vm.architectureBits)
          .thenReturn(64);
      when(fakeServiceConnection.serviceManager.vm.operatingSystem)
          .thenReturn('android');
      final app = fakeServiceConnection.serviceManager.connectedApp!;
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());
    }

    setUp(() {
      initServiceManager();
    });

    testWidgetsWithWindowSize(
      'displays without error',
      const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
        // Build our app and trigger a frame.
        await tester.pumpWidget(wrap(const HomeScreenBody()));
        expect(find.byType(ConnectionSection), findsOneWidget);
        expect(find.byType(ConnectDialog), findsNothing);
        expect(find.byType(ConnectToNewAppButton), findsOneWidget);
        expect(find.byType(ViewVmFlagsButton), findsOneWidget);
        expect(find.byType(SampleDataDropDownButton), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'does not display sample data picker',
      const Size(2000.0, 2000.0),
      (WidgetTester tester) async {
        // Build our app and trigger a frame.
        await tester.pumpWidget(
          wrap(
            HomeScreenBody(
              sampleData: [
                DevToolsJsonFile(
                  name: 'test-data',
                  lastModifiedTime: DateTime.now(),
                  data: <String, Object?>{},
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SampleDataDropDownButton), findsNothing);
      },
    );
  });
}
