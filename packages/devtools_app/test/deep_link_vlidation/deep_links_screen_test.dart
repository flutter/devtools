// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_link_list_view.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/shared/directory_picker.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
  });

  late DeepLinksScreen screen;
  late DeepLinksController deepLinksController;

  const windowSize = Size(2560.0, 1338.0);

  Future<void> pumpDeepLinkScreen(
    WidgetTester tester, {
    required DeepLinksController controller,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DeepLinkPage(),
        deepLink: controller,
      ),
    );
    deferredLoadingSupportEnabled = true;
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(DeepLinkPage), findsOneWidget);
  }

  group('DeepLinkScreen', () {
    setUp(() {
      screen = DeepLinksScreen();
      deepLinksController = DeepLinksTestController();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.buildTab),
          deepLink: deepLinksController,
        ),
      );
      expect(find.text('Deep Links'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds initial content',
      windowSize,
      (WidgetTester tester) async {
        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DirectoryPicker), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'builds deeplink list page',
      windowSize,
      (WidgetTester tester) async {
        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);
        deepLinksController.allLinkDatasNotifier.value = [
          LinkData(
            domain: 'www.google.com',
            path: '/',
            os: [PlatformOS.android],
          ),
        ];
        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
      },
    );
  });
}

class DeepLinksTestController extends DeepLinksController {
  @override
  void validateLinks() async {}
}
