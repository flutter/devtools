// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/scaffold.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app/src/shared/query_parameters.dart';
import 'package:devtools_app/src/shared/survey.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockServiceConnectionManager mockServiceConnection;

  setUp(() {
    mockServiceConnection = createMockServiceConnectionWithDefaults();
    final mockServiceManager =
        mockServiceConnection.serviceManager as MockServiceManager;
    when(mockServiceManager.service).thenReturn(null);
    when(mockServiceManager.connectedAppInitialized).thenReturn(false);
    when(mockServiceManager.connectedState).thenReturn(
      ValueNotifier<ConnectedState>(const ConnectedState(false)),
    );
    when(mockServiceManager.hasConnection).thenReturn(false);

    final mockErrorBadgeManager = MockErrorBadgeManager();
    when(mockServiceConnection.errorBadgeManager)
        .thenReturn(mockErrorBadgeManager);
    when(mockErrorBadgeManager.errorCountNotifier(any))
        .thenReturn(ValueNotifier<int>(0));

    setGlobal(ServiceConnectionManager, mockServiceConnection);
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
    setGlobal(OfflineDataController, OfflineDataController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
  });

  Widget wrapScaffold(Widget child, {DevToolsQueryParams? queryParams}) {
    return wrapWithControllers(
      child,
      analytics: AnalyticsController(
        enabled: false,
        shouldShowConsentMessage: false,
        consentMessage: 'fake message',
      ),
      releaseNotes: ReleaseNotesController(),
      queryParams: queryParams,
    );
  }

  testWidgetsWithWindowSize(
    'does not show tab overflow button when screen is wide',
    const Size(2000.0, 1200.0),
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(
            page: _screen1.screenId,
            screens: const [_screen1, _screen2, _screen3, _screen4, _screen5],
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsOneWidget);
      expect(find.byKey(_k1), findsOneWidget);

      expect(find.byKey(_t1), findsOneWidget);
      expect(find.byKey(_t2), findsOneWidget);
      expect(find.byKey(_t3), findsOneWidget);
      expect(find.byKey(_t4), findsOneWidget);
      expect(find.byKey(_t5), findsOneWidget);

      expect(find.byType(TabOverflowButton), findsNothing);
    },
  );

  testWidgetsWithWindowSize(
    'shows tab overflow button when screen is narrow',
    const Size(600.0, 1200.0),
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(
            page: _screen1.screenId,
            screens: const [_screen1, _screen2, _screen3, _screen4, _screen5],
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsOneWidget);
      expect(find.byKey(_k1), findsOneWidget);

      expect(find.byKey(_t1), findsOneWidget);
      expect(find.byKey(_t2), findsOneWidget);
      expect(find.byKey(_t3), findsNothing);
      expect(find.byKey(_t4), findsNothing);
      expect(find.byKey(_t5), findsNothing);

      expect(find.byType(TabOverflowButton), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'can select screen from tab overflow menu',
    const Size(600.0, 1200.0),
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(
            page: _screen1.screenId,
            screens: const [_screen1, _screen2, _screen3, _screen4, _screen5],
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsOneWidget);
      expect(find.byKey(_k1), findsOneWidget);

      expect(find.byKey(_t1), findsOneWidget);
      expect(find.byKey(_t2), findsOneWidget);
      expect(find.byKey(_t3), findsNothing);
      expect(find.byKey(_t4), findsNothing);
      expect(find.byKey(_t5), findsNothing);
      expect(find.byType(TabOverflowButton), findsOneWidget);

      await tester.tap(find.byType(TabOverflowButton));
      await tester.pumpAndSettle();

      // The overflow tabs should now be shown in the context menu.
      expect(find.byKey(_t3), findsOneWidget);
      expect(find.byKey(_t4), findsOneWidget);
      expect(find.byKey(_t5), findsOneWidget);
      expect(find.byType(SelectedTabWrapper), findsNothing);

      // Select a tab in the overflow menu.
      await tester.tap(find.byKey(_t5));
      await tester.pumpAndSettle();

      // The overflow tabs should now be hidden again.
      expect(find.byKey(_t3), findsNothing);
      expect(find.byKey(_t4), findsNothing);
      expect(find.byKey(_t5), findsNothing);

      // The [TabOverflowButton] should now show up as selected.
      expect(
        find.descendant(
          of: find.byType(TabOverflowButton),
          matching: find.byType(SelectedTabWrapper),
        ),
        findsOneWidget,
      );

      expect(find.byKey(_k1), findsNothing);
      expect(find.byKey(_k5), findsOneWidget);
    },
  );

  testWidgets(
    'displays no tabs when only one is given',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(page: _screen1.screenId, screens: const [_screen1]),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsOneWidget);
      expect(find.byKey(_k1), findsOneWidget);
      expect(find.byKey(_t1), findsNothing);
    },
  );

  testWidgets('displays only the selected screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScaffold(
        DevToolsScaffold(
          page: _screen1.screenId,
          screens: const [_screen1, _screen2],
        ),
      ),
    );
    expect(find.byType(DevToolsAppBar), findsOneWidget);
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(_k2), findsNothing);

    // Tap on the tab for screen 2, then let the animation finish before
    // checking the body is updated.
    await tester.tap(find.byKey(_t2));
    await tester.pumpAndSettle();
    expect(find.byKey(_k1), findsNothing);
    expect(find.byKey(_k2), findsOneWidget);

    // Return to screen 1.
    await tester.tap(find.byKey(_t1));
    await tester.pumpAndSettle();
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(_k2), findsNothing);
  });

  testWidgets(
    'displays the requested initial page',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(
            screens: const [_screen1, _screen2],
            page: _screen2.screenId,
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsOneWidget);

      expect(find.byKey(_k1), findsNothing);
      expect(find.byKey(_k2), findsOneWidget);
    },
  );

  testWidgets(
    'hides the app bar for EmbedMode.embedOne',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(
            screens: const [_screen1, _screen2],
            page: _screen2.screenId,
            embedMode: EmbedMode.embedOne,
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsNothing);
    },
  );

  testWidgets(
    'hides the app bar for EmbedMode.embedMany with a single simple screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold.withChild(
            embedMode: EmbedMode.embedMany,
            child: const Center(child: Text('some message')),
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsNothing);
    },
  );

  testWidgets(
    'shows the app bar for EmbedMode.embedMany',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapScaffold(
          DevToolsScaffold(
            screens: const [_screen2],
            page: _screen2.screenId,
            embedMode: EmbedMode.embedMany,
          ),
        ),
      );
      expect(find.byType(DevToolsAppBar), findsOneWidget);
    },
  );

  testWidgets(
    'uses empty actions as default when embedded',
    (WidgetTester tester) async {
      var scaffold = DevToolsScaffold(
        screens: const [_screen1, _screen2],
        page: _screen1.screenId,
      );
      expect(scaffold.actions.length, 4);

      scaffold = DevToolsScaffold(
        screens: const [_screen1, _screen2],
        page: _screen1.screenId,
        embedMode: EmbedMode.embedOne,
      );
      expect(scaffold.actions, isEmpty);

      scaffold = DevToolsScaffold(
        screens: const [_screen1, _screen2],
        page: _screen1.screenId,
        embedMode: EmbedMode.embedMany,
      );
      expect(scaffold.actions, isEmpty);
    },
  );
}

class _TestScreen extends Screen {
  const _TestScreen(
    this.name,
    this.key, {
    bool showFloatingDebuggerControls = true,
    Key? tabKey,
  }) : super(
          name,
          title: name,
          icon: Icons.computer,
          tabKey: tabKey,
          showFloatingDebuggerControls: showFloatingDebuggerControls,
        );

  final String name;
  final Key key;

  @override
  Widget buildScreenBody(BuildContext context) {
    return SizedBox(key: key);
  }
}

// Keys and tabs for use in the test.
const _k1 = Key('body key 1');
const _k2 = Key('body key 2');
const _k3 = Key('body key 3');
const _k4 = Key('body key 4');
const _k5 = Key('body key 5');
const _t1 = Key('tab key 1');
const _t2 = Key('tab key 2');
const _t3 = Key('tab key 3');
const _t4 = Key('tab key 4');
const _t5 = Key('tab key 5');
const _screen1 = _TestScreen('screen1', _k1, tabKey: _t1);
const _screen2 = _TestScreen('screen2', _k2, tabKey: _t2);
const _screen3 = _TestScreen('screen3', _k3, tabKey: _t3);
const _screen4 = _TestScreen('screen4', _k4, tabKey: _t4);
const _screen5 = _TestScreen('screen5', _k5, tabKey: _t5);
