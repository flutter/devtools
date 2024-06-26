// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/project_root_selection/root_selector.dart';
import 'package:devtools_app/src/screens/deep_link_validation/project_root_selection/select_project_view.dart';
import 'package:devtools_app/src/shared/ui/utils.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/utils/deep_links_utils.dart';

void main() {
  // ignore: avoid-redundant-async, false positive.
  setUp(() async {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    final mockDtdManager = MockDTDManager();
    final rootUri1 = Uri.parse('file:///Users/me/package_root_1');
    final rootUri2 = Uri.parse('file:///Users/me/package_root_2');
    when(mockDtdManager.projectRoots()).thenAnswer((_) async {
      return UriList(uris: [rootUri1, rootUri2]);
    });
    setGlobal(DTDManager, mockDtdManager);
  });

  late DeepLinksController deepLinksController;

  const windowSize = Size(1000.0, 1000.0);

  Future<void> pumpSelectProjectView(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const SelectProjectView(),
        deepLink: deepLinksController,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SelectProjectView), findsOneWidget);
  }

  group('$SelectProjectView', () {
    setUp(() {
      deepLinksController = DeepLinksTestController();
    });

    testWidgetsWithWindowSize(
      'builds content',
      windowSize,
      (WidgetTester tester) async {
        await pumpSelectProjectView(tester);
        expect(
          find.textContaining('Select a local flutter project to check'),
          findsOneWidget,
        );
        expect(find.byType(ProjectRootsDropdown), findsOneWidget);
        expect(
          find.textContaining('Don\'t see your project in the list?'),
          findsOneWidget,
        );
        expect(find.byType(ProjectRootTextField), findsOneWidget);

        expect(
          find.descendant(
            of: find.byType(ProjectRootsDropdown),
            matching: find.byType(Column),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(ProjectRootTextField),
            matching: find.byType(Column),
          ),
          findsNothing,
        );
      },
    );

    testWidgetsWithWindowSize(
      'builds content for narrow screen',
      Size(MediaSize.xs.widthThreshold - 1, 1000.0),
      (WidgetTester tester) async {
        await pumpSelectProjectView(tester);
        expect(
          find.textContaining('Select a local flutter project to check'),
          findsOneWidget,
        );
        expect(find.byType(ProjectRootsDropdown), findsOneWidget);
        expect(
          find.textContaining('Don\'t see your project in the list?'),
          findsOneWidget,
        );
        expect(find.byType(ProjectRootTextField), findsOneWidget);

        // Since this is a narrow screen size, each project selection widget
        // should contain a column, where the validate button has been placed
        // below the project selection widget.
        expect(
          find.descendant(
            of: find.byType(ProjectRootsDropdown),
            matching: find.byType(Column),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(ProjectRootTextField),
            matching: find.byType(Column),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
