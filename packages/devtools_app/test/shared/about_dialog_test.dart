// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools.dart' as devtools;
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/about_dialog.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late DevToolsAboutDialog aboutDialog;

  group('About Dialog', () {
    setUp(() {
      aboutDialog = DevToolsAboutDialog(ReleaseNotesController());
      final fakeServiceConnection = FakeServiceConnectionManager();
      when(fakeServiceConnection.serviceManager.vm.version).thenReturn('1.9.1');
      when(fakeServiceConnection.serviceManager.vm.targetCPU)
          .thenReturn('arm64');
      when(fakeServiceConnection.serviceManager.vm.architectureBits)
          .thenReturn(64);
      when(fakeServiceConnection.serviceManager.vm.operatingSystem)
          .thenReturn('android');

      mockConnectedApp(
        fakeServiceConnection.serviceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(IdeTheme, IdeTheme());
    });

    testWidgets('builds dialog', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('About DevTools'), findsOneWidget);
    });

    testWidgets('content renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('About DevTools'), findsOneWidget);
      expect(findSubstring(devtools.version), findsOneWidget);
      expect(find.text('release notes'), findsOneWidget);
      expect(find.textContaining('Encountered an issue?'), findsOneWidget);
      expect(
        findSubstring('github.com/flutter/devtools/issues/new'),
        findsOneWidget,
      );
      expect(find.text('Contributing'), findsOneWidget);
      expect(
        find.textContaining('Want to contribute to DevTools?'),
        findsOneWidget,
      );
      expect(findSubstring('CONTRIBUTING'), findsOneWidget);
      expect(find.textContaining('connect with us on'), findsOneWidget);
      expect(
        findSubstring('Discord'),
        findsOneWidget,
      );
    });
  });
}
