// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_link_list_view.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/screens/deep_link_validation/project_root_selection/root_selector.dart';
import 'package:devtools_app/src/screens/deep_link_validation/project_root_selection/select_project_view.dart';
import 'package:devtools_app/src/screens/deep_link_validation/validation_details_view.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../test_infra/test_data/deep_link/fake_responses.dart';
import '../../test_infra/utils/deep_links_utils.dart';

final xcodeBuildOptions = XcodeBuildOptions.fromJson(
  '''{"configurations":["debug", "release"],"targets":["runner","runnerTests"]}''',
);

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
    FeatureFlags.deepLinkIosCheck = true;
  });

  late DeepLinksScreen screen;
  late TestDeepLinksController deepLinksController;

  const windowSize = Size(2560.0, 1338.0);

  Future<void> pumpDeepLinkScreen(
    WidgetTester tester, {
    required DeepLinksController controller,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(const DeepLinkPage(), deepLink: controller),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeepLinkPage), findsOneWidget);
  }

  group('DeepLinkScreen', () {
    setUp(() {
      screen = DeepLinksScreen();
      deepLinksController = TestDeepLinksController();
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

    testWidgetsWithWindowSize('builds initial content', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      expect(find.byType(SelectProjectView), findsOneWidget);
      expect(find.byType(ProjectRootsDropdown), findsOneWidget);
      expect(find.byType(ProjectRootTextField), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds deeplink list page with no links',
      windowSize,
      (WidgetTester tester) async {
        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = []
          ..fakeIosDomains = [];
        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(deepLinksController.pagePhase.value, PagePhase.noLinks);
        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'builds deeplink list page with links',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController();

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [defaultAndroidDeeplink]
          ..fakeIosDomains = [defaultDomain];
        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(deepLinksController.pagePhase.value, PagePhase.linksValidated);
        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(ValidationDetailView), findsNothing);
      },
    );

    testWidgetsWithWindowSize(
      'builds deeplink list page with default ios and android configurations',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController();

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'profile', 'release'],
            iosBuildOptions: XcodeBuildOptions.fromJson(
              '''{"configurations":["debug", "release"],"targets":["runner","runnerTests"]}''',
            ),
          )
          ..fakeAndroidDeepLinks = [defaultAndroidDeeplink]
          ..fakeIosDomains = [defaultDomain];
        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(deepLinksController.pagePhase.value, PagePhase.linksValidated);
        expect(deepLinksController.selectedAndroidVariantIndex.value, 2);
        expect(deepLinksController.selectedIosConfigurationIndex.value, 1);
        expect(deepLinksController.selectedIosTargetIndex.value, 0);
      },
    );

    testWidgetsWithWindowSize(
      'builds deeplink list page with split screen',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController();

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [defaultAndroidDeeplink]
          ..fakeIosDomains = [defaultDomain];

        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        deepLinksController.autoSelectLink(TableViewType.domainView);
        deepLinksController.displayOptionsNotifier.value = DisplayOptions(
          showSplitScreen: true,
        );

        await tester.pumpAndSettle();

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(ValidationDetailView), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'shows notification cards when there are domain errors',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController(
          hasAndroidDomainErrors: true,
          iosValidationResponse: iosValidationResponseWithError,
        );
        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [defaultAndroidDeeplink]
          ..fakeIosDomains = [defaultDomain];

        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(NotificationCard), findsOneWidget);
      },
    );
    testWidgetsWithWindowSize(
      'shows notification cards when there are path errors',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController();

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [
            androidDeepLinkJson(defaultDomain, hasPathError: true),
          ]
          ..fakeIosDomains = [defaultDomain];
        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(NotificationCard), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'taps the action button in notification cards to go to the split screen',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController(
          hasAndroidDomainErrors: true,
          iosValidationResponse: iosValidationResponseWithError,
        );

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [defaultAndroidDeeplink]
          ..fakeIosDomains = [defaultDomain];

        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        await tester.tap(find.text('Fix domain'));
        await tester.pumpAndSettle();

        expect(find.byType(DeepLinkPage), findsOneWidget);
        expect(find.byType(DeepLinkListView), findsOneWidget);
        expect(find.byType(NotificationCard), findsNothing);
        expect(find.byType(ValidationDetailView), findsOneWidget);
        expect(find.text('Digital assets link file'), findsOneWidget);
        expect(find.text('Apple-App-Site-Association file'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'Don\'t show domain errors when they are just warnings',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController(
          iosValidationResponse: iosValidationResponseWithWarning,
        );

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [
            androidDeepLinkJson('www.domain1.com'),
            androidDeepLinkJson('www.google.com'),
          ]
          ..fakeIosDomains = [defaultDomain];

        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('example.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        await tester.tap(find.text('example.com'));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        final domainErrors =
            deepLinksController.selectedLink.value!.domainErrors;
        expect(domainErrors.length, 0);
      },
    );

    testWidgetsWithWindowSize('search links', windowSize, (
      WidgetTester tester,
    ) async {
      final deepLinksController = TestDeepLinksController();

      deepLinksController
        ..selectedProject.value = FlutterProject(
          path: '/abc',
          androidVariants: ['debug', 'release'],
          iosBuildOptions: xcodeBuildOptions,
        )
        ..fakeAndroidDeepLinks = [defaultAndroidDeeplink]
        ..fakeIosDomains = [
          'www.domain1.com',
          'www.domain2.com',
          'www.google.com',
        ];

      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      expect(find.text('www.domain1.com'), findsOneWidget);
      expect(find.text('www.domain2.com'), findsOneWidget);
      expect(find.text('www.google.com'), findsOneWidget);

      deepLinksController.searchContent = 'goo';

      await tester.pumpAndSettle();

      expect(find.text('www.domain1.com'), findsNothing);
      expect(find.text('www.domain2.com'), findsNothing);
      expect(find.text('www.google.com'), findsOneWidget);
    });

    testWidgetsWithWindowSize('filter links with os', windowSize, (
      WidgetTester tester,
    ) async {
      final deepLinksController = TestDeepLinksController();
      deepLinksController
        ..selectedProject.value = FlutterProject(
          path: '/abc',
          androidVariants: ['debug', 'release'],
          iosBuildOptions: xcodeBuildOptions,
        )
        ..fakeAndroidDeepLinks = [
          androidDeepLinkJson('www.domain1.com'),
          androidDeepLinkJson('www.google.com'),
        ]
        ..fakeIosDomains = ['www.domain2.com', 'www.google.com'];

      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      expect(find.text('www.domain1.com'), findsOneWidget);
      expect(find.text('www.domain2.com'), findsOneWidget);
      expect(find.text('www.google.com'), findsOneWidget);

      // Only show Android links.
      deepLinksController.updateDisplayOptions(removedFilter: FilterOption.ios);

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
    });

    testWidgetsWithWindowSize(
      'filter links with validation result',
      windowSize,
      (WidgetTester tester) async {
        final deepLinksController = TestDeepLinksController(
          iosValidationResponse: iosValidationResponseWithError,
        );

        deepLinksController
          ..selectedProject.value = FlutterProject(
            path: '/abc',
            androidVariants: ['debug', 'release'],
            iosBuildOptions: xcodeBuildOptions,
          )
          ..fakeAndroidDeepLinks = [
            androidDeepLinkJson('www.domain1.com'),
            androidDeepLinkJson('www.google.com'),
          ]
          ..fakeIosDomains = [defaultDomain];

        await pumpDeepLinkScreen(tester, controller: deepLinksController);

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('example.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsOneWidget);

        // Only show links with domain error.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.noIssue,
        );

        await tester.pumpAndSettle();
        expect(find.text('www.domain1.com'), findsNothing);
        expect(find.text('example.com'), findsOneWidget);
        expect(find.text('www.google.com'), findsNothing);

        // Only show links with no issue.
        deepLinksController.updateDisplayOptions(
          removedFilter: FilterOption.failedDomainCheck,
        );
        deepLinksController.updateDisplayOptions(
          addedFilter: FilterOption.noIssue,
        );

        await tester.pumpAndSettle();

        expect(find.text('www.domain1.com'), findsOneWidget);
        expect(find.text('example.com'), findsNothing);
        expect(find.text('www.google.com'), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize('domain errors are correct', windowSize, (
      WidgetTester tester,
    ) async {
      final deepLinksController = TestDeepLinksController(
        iosValidationResponse: iosValidationResponseWithError,
      );

      deepLinksController
        ..selectedProject.value = FlutterProject(
          path: '/abc',
          androidVariants: ['debug', 'release'],
          iosBuildOptions: xcodeBuildOptions,
        )
        ..fakeAndroidDeepLinks = [
          androidDeepLinkJson('www.domain1.com'),
          androidDeepLinkJson('www.google.com'),
        ]
        ..fakeIosDomains = [defaultDomain];

      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      expect(find.text('www.domain1.com'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('www.google.com'), findsOneWidget);

      await tester.tap(find.text('example.com'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final domainErrors = deepLinksController.selectedLink.value!.domainErrors;
      expect(domainErrors.length, 3);
      expect(domainErrors[0], IosDomainError.existence);
      expect(domainErrors[1].title, IosDomainError.appIdentifier.title);
      expect(
        (domainErrors[2] as IosDomainError).subcheckErrors.single,
        AASAfileFormatSubCheck.componentPercentEncodedFormat,
      );
    });

    testWidgetsWithWindowSize('sort links', windowSize, (
      WidgetTester tester,
    ) async {
      final deepLinksController = TestDeepLinksController(
        iosValidationResponse: iosValidationResponseWithError,
      );

      deepLinksController
        ..selectedProject.value = FlutterProject(
          path: '/abc',
          androidVariants: ['debug', 'release'],
          iosBuildOptions: xcodeBuildOptions,
        )
        ..fakeIosDomains = [defaultDomain, 'domain1.com', 'domain2.com'];

      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      expect(find.text('domain1.com'), findsOneWidget);
      expect(find.text('domain2.com'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);

      // Sort with a-z.
      deepLinksController.updateDisplayOptions(
        domainSortingOption: SortingOption.aToZ,
      );
      await tester.pumpAndSettle();

      var widgetACenter = tester.getCenter(find.text('domain1.com'));
      var widgetBCenter = tester.getCenter(find.text('domain2.com'));
      var widgetCCenter = tester.getCenter(find.text('example.com'));

      expect(widgetACenter.dy < widgetBCenter.dy, true);
      expect(widgetBCenter.dy < widgetCCenter.dy, true);

      // Sort with z-a.
      deepLinksController.updateDisplayOptions(
        domainSortingOption: SortingOption.zToA,
      );
      await tester.pumpAndSettle();

      widgetACenter = tester.getCenter(find.text('domain1.com'));
      widgetBCenter = tester.getCenter(find.text('domain2.com'));
      widgetCCenter = tester.getCenter(find.text('example.com'));

      expect(widgetCCenter.dy < widgetBCenter.dy, true);
      expect(widgetBCenter.dy < widgetACenter.dy, true);

      // Sort with error on top. `example.com` is the one with error.
      deepLinksController.updateDisplayOptions(
        domainSortingOption: SortingOption.errorOnTop,
      );
      await tester.pumpAndSettle();

      widgetACenter = tester.getCenter(find.text('domain1.com'));
      widgetBCenter = tester.getCenter(find.text('domain2.com'));
      widgetCCenter = tester.getCenter(find.text('example.com'));

      expect(widgetCCenter.dy < widgetACenter.dy, true);
      expect(widgetCCenter.dy < widgetBCenter.dy, true);
    });

    testWidgetsWithWindowSize('show scheme or missing scheme', windowSize, (
      WidgetTester tester,
    ) async {
      final deepLinksController = TestDeepLinksController();

      deepLinksController
        ..selectedProject.value = FlutterProject(
          path: '/abc',
          androidVariants: ['debug', 'release'],
          iosBuildOptions: xcodeBuildOptions,
        )
        ..fakeAndroidDeepLinks = [
          androidDeepLinkJson('www.domain1.com'),
          androidDeepLinkJson('www.domain2.com', scheme: null),
        ];

      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      expect(find.text('www.domain1.com'), findsOneWidget);
      expect(find.text('www.domain2.com'), findsOneWidget);

      expect(find.text('missing scheme'), findsOneWidget);
      expect(find.text('http'), findsOneWidget);
    });

    testWidgetsWithWindowSize('path view', windowSize, (
      WidgetTester tester,
    ) async {
      final deepLinksController = TestDeepLinksController();

      deepLinksController
        ..selectedProject.value = FlutterProject(
          path: '/abc',
          androidVariants: ['debug', 'release'],
          iosBuildOptions: xcodeBuildOptions,
        )
        ..fakeAndroidDeepLinks = [
          androidDeepLinkJson('www.domain1.com', path: '/path1'),
          androidDeepLinkJson(
            'www.domain2.com',
            path: '/path2',
            hasPathError: true,
          ),
          androidDeepLinkJson('www.domain3.com', path: '/path3'),
        ]
        ..fakeIosDomains = [defaultDomain];

      await pumpDeepLinkScreen(tester, controller: deepLinksController);

      await tester.tap(find.text('Path view'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('/path1'), findsOneWidget);
      expect(find.text('/path2'), findsOneWidget);
      expect(find.text('/path3'), findsOneWidget);
      expect(find.text('/ios-path1'), findsOneWidget);
      expect(find.text('NOT /ios-path2'), findsOneWidget);

      // Only show links with path error.
      deepLinksController.updateDisplayOptions(
        removedFilter: FilterOption.noIssue,
      );

      await tester.pumpAndSettle();

      expect(find.text('/path1'), findsNothing);
      expect(find.text('/path2'), findsOneWidget);
      expect(find.text('/path3'), findsNothing);
      expect(find.text('/ios-path1'), findsNothing);
      expect(find.text('NOT /ios-path2'), findsNothing);

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
      expect(find.text('/ios-path1'), findsOneWidget);
      expect(find.text('NOT /ios-path2'), findsOneWidget);
    });
  });
}
