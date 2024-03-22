// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_link_list_view.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_services.dart';
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

final pathErrorlinkData = LinkData(
  domain: 'www.google.com',
  path: '/abcd',
  os: [PlatformOS.android, PlatformOS.ios],
  pathErrors: {
    PathError.intentFilterActionView,
    PathError.intentFilterDefault,
  },
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

        expect(deepLinksController.pagePhase.value, PagePhase.linksLoading);
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

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: linkDatas,
          byDomain: deepLinksController.linkDatasByDomain(linkDatas),
          byPath: deepLinksController.linkDatasByPath(linkDatas),
        );
        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(deepLinksController.pagePhase.value, PagePhase.linksValidated);
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

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: linkDatas,
          byDomain: deepLinksController.linkDatasByDomain(linkDatas),
          byPath: deepLinksController.linkDatasByPath(linkDatas),
        );

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
      'shows notification cards when there are domain errors',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: [domainErrorlinkData],
          byDomain: [domainErrorlinkData],
          byPath: [domainErrorlinkData],
        );

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
      'shows notification cards when there are path errors',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: [pathErrorlinkData],
          byDomain: [pathErrorlinkData],
          byPath: [pathErrorlinkData],
        );
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
        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: [domainErrorlinkData],
          byDomain: [domainErrorlinkData],
          byPath: [domainErrorlinkData],
        );

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

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: linkDatas,
          byDomain: deepLinksController.linkDatasByDomain(linkDatas),
          byPath: deepLinksController.linkDatasByPath(linkDatas),
        );

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

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: linkDatas,
          byDomain: deepLinksController.linkDatasByDomain(linkDatas),
          byPath: deepLinksController.linkDatasByPath(linkDatas),
        );

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        // Only show Android links.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.ios,
        );

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('www.domain2.com'), findsNothing);
        expect(find.text('www.google.com'), findsOneWidget);

        // Only show iOS links.
        deepLinksController.updateDisplayOptions(
          addedFilter: FilterOption.ios,
          removedFilter: FilterOption.android,
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
            pathErrors: {PathError.intentFilterActionView},
          ),
          LinkData(
            domain: 'www.google.com',
            path: '/',
            os: [PlatformOS.android, PlatformOS.ios],
          ),
        ];

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: linkDatas,
          byDomain: deepLinksController.linkDatasByDomain(linkDatas),
          byPath: deepLinksController.linkDatasByPath(linkDatas),
        );

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
    // TODO(hangyujin): Fix the sorting issue.
    // testWidgetsWithWindowSize(
    //   'sort links',
    //   windowSize,
    //   (WidgetTester tester) async {
    //     final deepLinksController = DeepLinksTestController();
    //     final linkDatas = [
    //       LinkData(
    //         domain: 'www.domain1.com',
    //         path: '/',
    //         os: [PlatformOS.android],
    //       ),
    //       LinkData(
    //         domain: 'www.domain2.com',
    //         path: '/path',
    //         os: [PlatformOS.ios],
    //         domainErrors: [DomainError.existence],
    //       ),
    //       LinkData(
    //         domain: 'www.google.com',
    //         path: '/',
    //         os: [PlatformOS.android, PlatformOS.ios],
    //       ),
    //     ];

    //     deepLinksController.selectedProject.value =
    //         FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);
    //     deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
    //       all: linkDatas,
    //       byDomain: deepLinksController.linkDatasByDomain(linkDatas),
    //       byPath: deepLinksController.linkDatasByPath(linkDatas),
    //     );

    //     await pumpDeepLinkScreen(
    //       tester,
    //       controller: deepLinksController,
    //     );

    //     expect(find.text('www.domain1.com'), findsOneWidget);
    //     expect(find.text('www.domain2.com'), findsOneWidget);
    //     expect(find.text('www.google.com'), findsOneWidget);

    //     // Sort with a-z.
    //     deepLinksController.updateDisplayOptions(
    //       domainSortingOption: SortingOption.aToZ,
    //     );
    //     await tester.pumpAndSettle();

    //     var widgetACenter = tester.getCenter(find.text('www.domain1.com'));
    //     var widgetBCenter = tester.getCenter(find.text('www.domain2.com'));
    //     var widgetCCenter = tester.getCenter(find.text('www.google.com'));

    //     expect(widgetACenter.dy < widgetBCenter.dy, true);
    //     expect(widgetBCenter.dy < widgetCCenter.dy, true);

    //     // Sort with z-a.
    //     deepLinksController.updateDisplayOptions(
    //       domainSortingOption: SortingOption.zToA,
    //     );
    //     await tester.pumpAndSettle();

    //     widgetACenter = tester.getCenter(find.text('www.domain1.com'));
    //     widgetBCenter = tester.getCenter(find.text('www.domain2.com'));
    //     widgetCCenter = tester.getCenter(find.text('www.google.com'));

    //     expect(widgetCCenter.dy < widgetBCenter.dy, true);
    //     expect(widgetBCenter.dy < widgetACenter.dy, true);

    //     // Sort with error on top.
    //     deepLinksController.updateDisplayOptions(
    //       domainSortingOption: SortingOption.errorOnTop,
    //     );
    //     await tester.pumpAndSettle();

    //     widgetACenter = tester.getCenter(find.text('www.domain1.com'));
    //     widgetBCenter = tester.getCenter(find.text('www.domain2.com'));
    //     widgetCCenter = tester.getCenter(find.text('www.google.com'));

    //     expect(widgetBCenter.dy < widgetACenter.dy, true);
    //     expect(widgetBCenter.dy < widgetCCenter.dy, true);
    //   },
    // );

    testWidgetsWithWindowSize(
      'path view',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = DeepLinksTestController();

        deepLinksController.selectedProject.value =
            FlutterProject(path: '/abc', androidVariants: ['debug', 'release']);

        final linkDatas = [
          LinkData(
            domain: 'www.domain1.com',
            path: '/path1',
            os: [PlatformOS.android],
            domainErrors: [DomainError.existence],
          ),
          LinkData(
            domain: 'www.domain2.com',
            path: '/path2',
            os: [PlatformOS.ios],
            pathErrors: {PathError.intentFilterActionView},
          ),
          LinkData(
            domain: 'www.google.com',
            path: '/path3',
            os: [PlatformOS.android, PlatformOS.ios],
          ),
        ];

        deepLinksController.validatedLinkDatas = ValidatedLinkDatas(
          all: linkDatas,
          byDomain: deepLinksController.linkDatasByDomain(linkDatas),
          byPath: deepLinksController.linkDatasByPath(linkDatas),
        );

        await pumpDeepLinkScreen(
          tester,
          controller: deepLinksController,
        );

        await tester.tap(find.text('Path view'));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        expect(find.text('/path1'), findsOneWidget);
        expect(find.text('/path2'), findsOneWidget);
        expect(find.text('/path3'), findsOneWidget);

        // Only show links with path error.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.noIssue,
        );

        await tester.pumpAndSettle();

        expect(find.text('/path1'), findsNothing);
        expect(find.text('/path2'), findsOneWidget);
        expect(find.text('/path3'), findsNothing);

        // Only show links with no issue.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.failedPathCheck,
        );
        deepLinksController.updateDisplayOptions(
          addedFilter: FilterOption.noIssue,
        );

        await tester.pumpAndSettle();

        expect(find.text('/path1'), findsOneWidget);
        expect(find.text('/path2'), findsNothing);
        expect(find.text('/path3'), findsOneWidget);
      },
    );
  });
}

class DeepLinksTestController extends DeepLinksController {
  @override
  Future<String?> packageDirectoryForMainIsolate() async {
    return null;
  }

  @override
  Future<void> validateLinks() async {
    if (validatedLinkDatas.all.isEmpty) {
      return;
    }
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: validatedLinkDatas.byDomain
          .where((element) => element.domainErrors.isNotEmpty)
          .length,
      pathErrorCount: validatedLinkDatas.byPath
          .where((element) => element.pathErrors.isNotEmpty)
          .length,
    );
    applyFilters();
    pagePhase.value = PagePhase.linksValidated;
  }

  @override
  void selectLink(LinkData linkdata) async {
    selectedLink.value = linkdata;
    if (linkdata.domainErrors.isNotEmpty) {
      generatedAssetLinksForSelectedLink.value = GenerateAssetLinksResult(
        '',
        'fake generated content',
      );
    }
  }
}
