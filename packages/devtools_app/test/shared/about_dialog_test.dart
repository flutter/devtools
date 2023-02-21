// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools.dart' as devtools;
import 'package:devtools_app/src/extension_points/extensions_base.dart';
import 'package:devtools_app/src/extension_points/extensions_external.dart';
import 'package:devtools_app/src/framework/about_dialog.dart';
import 'package:devtools_app/src/framework/release_notes/release_notes.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late DevToolsAboutDialog aboutDialog;

  group('About Dialog', () {
    setUp(() {
      aboutDialog = DevToolsAboutDialog(ReleaseNotesController());
      final fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.vm.version).thenReturn('1.9.1');
      when(fakeServiceManager.vm.targetCPU).thenReturn('arm64');
      when(fakeServiceManager.vm.architectureBits).thenReturn(64);
      when(fakeServiceManager.vm.operatingSystem).thenReturn('android');

      mockConnectedApp(
        fakeServiceManager.connectedApp!,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
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
