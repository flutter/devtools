// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_link_list_view.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/screens/deep_link_validation/validation_details_view.dart';
import 'package:devtools_app/src/shared/directory_picker.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final linkDatas = [
  LinkData(
    domain: 'www.domain1.com',
    path: '/',
    os: [PlatformOS.android],
  ),
  LinkData(
    domain: 'www.domain2.com',
    path: '/',
    os: [PlatformOS.ios],
  ),
  LinkData(
    domain: 'www.google.com',
    path: '/',
    os: [PlatformOS.android, PlatformOS.ios],
  ),
  LinkData(
    domain: 'www.google.com',
    path: '/home',
    os: [PlatformOS.android, PlatformOS.ios],
  ),
];

final domainErrorlinkData = LinkData(
  domain: 'www.google.com',
  path: '/',
  os: [PlatformOS.android, PlatformOS.ios],
  domainErrors: [DomainError.existence],
);

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
    await tester.pump(const Duration(seconds: 1));
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
      'builds deeplink list page with no links',
      windowSize,
      (WidgetTester tester) async {
        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);
        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'builds deeplink list page with links',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.allLinkDatasNotifier.value = linkDatas;

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(ValidationDetailView), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds deeplink list page with split screen',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.allLinkDatasNotifier.value = linkDatas;

        deepLinksController.displayOptionsNotifier.value =
            DisplayOptions(showSplitScreen: true);
        deepLinksController.selectedLink.value = linkDatas.first;

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(ValidationDetailView), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'shows notification cards when there are errors',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.allLinkDatasNotifier.value = [domainErrorlinkData];
        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(NotificationCard), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'taps the action button in notification cards to go to the split screen',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.allLinkDatasNotifier.value = [domainErrorlinkData];
        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        await tester.tap(find.text('Fix domain'));
        await tester.pumpAndSettle();

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(NotificationCard), findsNothing);
        expect(find.byType(ValidationDetailView), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'search links',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.allLinkDatasNotifier.value = linkDatas;

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        deepLinksController.searchContent = 'goo';

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsNothing);
        expect(find.text('www.domain2.com'), findsNothing);
        expect(find.text('www.google.com'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'filter links with os',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        final linkDatas = [
          LinkData(
            domain: 'www.domain1.com',
            path: '/',
            os: [PlatformOS.android],
          ),
          LinkData(
            domain: 'www.domain2.com',
            path: '/',
            os: [PlatformOS.ios],
          ),
          LinkData(
            domain: 'www.google.com',
            path: '/',
            os: [PlatformOS.android, PlatformOS.ios],
          ),
        ];

        deepLinksController.allLinkDatasNotifier.value = linkDatas;

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        // Only show Android links.
        deepLinksController.displayOptionsNotifier.value = DisplayOptions(
          filters: {
            FilterOption.http,
            FilterOption.custom,
            FilterOption.android,
            FilterOption.noIssue,
            FilterOption.failedDomainCheck,
            FilterOption.failedPathCheck,
          },
        );

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsNothing);
        expect(find.text('www.google.com'), findsOneWidget);

        // Only show iOS links.
        deepLinksController.displayOptionsNotifier.value = DisplayOptions(
          filters: {
            FilterOption.http,
            FilterOption.custom,
            FilterOption.ios,
            FilterOption.noIssue,
            FilterOption.failedDomainCheck,
            FilterOption.failedPathCheck,
          },
        );

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsNothing);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'filter links with validation result',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        final linkDatas = [
          LinkData(
            domain: 'www.domain1.com',
            path: '/',
            os: [PlatformOS.android],
            domainErrors: [DomainError.existence],
          ),
          LinkData(
            domain: 'www.domain2.com',
            path: '/path',
            os: [PlatformOS.ios],
            pathError: true,
          ),
          LinkData(
            domain: 'www.google.com',
            path: '/',
            os: [PlatformOS.android, PlatformOS.ios],
          ),
        ];

        deepLinksController.allLinkDatasNotifier.value = linkDatas;

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        // Only show links with domain error.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.noIssue,
        );

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsNothing);
        expect(find.text('www.google.com'), findsNothing);

        // Only show links with no issue.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.failedDomainCheck,
        );
        deepLinksController.updateDisplayOptions(
          addedFilter: FilterOption.noIssue,
        );

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsNothing);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'sort links',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();
        final linkDatas = [
          LinkData(
            domain: 'www.domain1.com',
            path: '/',
            os: [PlatformOS.android],
          ),
          LinkData(
            domain: 'www.domain2.com',
            path: '/path',
            os: [PlatformOS.ios],
            domainErrors: [DomainError.existence],
          ),
          LinkData(
            domain: 'www.google.com',
            path: '/',
            os: [PlatformOS.android, PlatformOS.ios],
          ),
        ];

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);
        deepLinksController.allLinkDatasNotifier.value = linkDatas;

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        // Sort with a-z.
        deepLinksController.updateDisplayOptions(
          domainSortingOption: SortingOption.aToZ,
        );
        await tester.pumpAndSettle();

        var widgetACenter = tester.getCenter(find.text('www.domain1.com'));
        var widgetBCenter = tester.getCenter(find.text('www.domain2.com'));
        var widgetCCenter = tester.getCenter(find.text('www.google.com'));

        expect(widgetACenter.dy < widgetBCenter.dy, true);
        expect(widgetBCenter.dy < widgetCCenter.dy, true);

        // Sort with z-a.
        deepLinksController.updateDisplayOptions(
          domainSortingOption: SortingOption.zToA,
        );
        await tester.pumpAndSettle();

        widgetACenter = tester.getCenter(find.text('www.domain1.com'));
        widgetBCenter = tester.getCenter(find.text('www.domain2.com'));
        widgetCCenter = tester.getCenter(find.text('www.google.com'));

        expect(widgetCCenter.dy < widgetBCenter.dy, true);
        expect(widgetBCenter.dy < widgetACenter.dy, true);

        // Sort with error on top.
        deepLinksController.updateDisplayOptions(
          domainSortingOption: SortingOption.errorOnTop,
        );
        await tester.pumpAndSettle();

        widgetACenter = tester.getCenter(find.text('www.domain1.com'));
        widgetBCenter = tester.getCenter(find.text('www.domain2.com'));
        widgetCCenter = tester.getCenter(find.text('www.google.com'));

        expect(widgetBCenter.dy < widgetACenter.dy, true);
        expect(widgetBCenter.dy < widgetCCenter.dy, true);
      },
    );
  });
}

class DeepLinksTestController extends DeepLinksController {
  @override
  Future<void> validateLinks() async {
    if (allLinkDatasNotifier.value == null) return;
    displayLinkDatasNotifier.value =
        getFilterredLinks(allLinkDatasNotifier.value!);

    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: getLinkDatasByDomain
          .where((element) => element.domainErrors.isNotEmpty)
          .length,
      pathErrorCount:
          getLinkDatasByPath.where((element) => element.pathError).length,
    );
  }

  @override
  void selectLink(LinkData linkdata) async {
    selectedLink.value = linkdata;
    if (linkdata.domainErrors.isNotEmpty) {
      generatedAssetLinksForSelectedLink.value = 'fake generated content';
    }
  }
}
