// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(bkonyi): add integration tests for navigation state.
// See https://github.com/flutter/devtools/issues/4902.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestController extends DisposableController with RouteStateHandlerMixin {
  int count = 0;

  @override
  void onRouteStateUpdate(DevToolsNavigationState state) {
    count++;
  }
}

void main() {
  late TestController controller;
  late GlobalKey<NavigatorState> navKey;
  late DevToolsRouterDelegate routerDelegate;

  const page = 'Test';
  const defaultArgs = <String, String>{};
  const updatedArgs = <String, String>{
    'arg': 'foo',
  };

  final originalState = DevToolsNavigationState(
    kind: 'Test',
    state: {
      'state': '1',
    },
  );

  late final duplicateOriginalState = DevToolsNavigationState(
    kind: originalState.kind,
    state: originalState.state,
  );

  final updatedState = DevToolsNavigationState(
    kind: 'Test',
    state: {
      'state': '2',
    },
  );

  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    controller = TestController();
    navKey = GlobalKey<NavigatorState>();
    routerDelegate = DevToolsRouterDelegate(
      (p0, p1, p2, p3) => const MaterialPage(child: SizedBox.shrink()),
      navKey,
    );
    controller.subscribeToRouterEvents(routerDelegate);
  });

  tearDown(() {
    controller.dispose();
  });

  void expectConfigArgs([Map<String, String> args = defaultArgs]) {
    expect(routerDelegate.currentConfiguration!.args, args);
  }

  group('Route state handler', () {
    test('state objects', () {
      expect(originalState.hasChanges(originalState), false);
      expect(originalState.hasChanges(updatedState), true);
    });

    test('gets basic router updates with state change', () {
      // Navigating with no state won't trigger the callback.
      routerDelegate.navigate(page);
      expect(controller.count, 0);
      expectConfigArgs();

      // Navigating to another page with state should result in the router
      // event callback being invoked.
      expect(controller.count, 0);
      routerDelegate.navigate(page, defaultArgs, originalState);
      expect(controller.count, 1);
      expectConfigArgs();

      // Navigating to the same page with identical state doesn't trigger the
      // callback
      controller.count = 0;
      routerDelegate.navigateIfNotCurrent(page, defaultArgs, originalState);
      expect(controller.count, 0);
      expectConfigArgs();

      // Navigating to the same page with updated state triggers callback.
      routerDelegate.navigateIfNotCurrent(page, defaultArgs, updatedState);
      expect(controller.count, 1);
      expectConfigArgs();
    });

    test('gets basic router updates with arg change', () {
      // Navigating with no args or state won't trigger the callback.
      routerDelegate.navigate(page);
      expect(controller.count, 0);
      expectConfigArgs();

      // Navigating to another page with args should result in the router
      // event callback being invoked.
      expect(controller.count, 0);
      routerDelegate.navigate(page, defaultArgs, originalState);
      expect(controller.count, 1);
      expectConfigArgs();

      // Navigating to the same page with identical args doesn't trigger the
      // callback
      controller.count = 0;
      routerDelegate.navigateIfNotCurrent(page, defaultArgs, originalState);
      expect(controller.count, 0);
      expectConfigArgs();

      // Navigating to the same page with updated args triggers callback.
      routerDelegate.navigateIfNotCurrent(page, updatedArgs, originalState);
      expect(controller.count, 1);
      expectConfigArgs(updatedArgs);
    });

    testWidgets('replaces state', (tester) async {
      WidgetsFlutterBinding.ensureInitialized();
      expect(controller.count, 0);

      routerDelegate.navigate(page, null, originalState);
      expect(controller.count, 1);
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(originalState),
        false,
      );

      await routerDelegate.replaceState(updatedState);
      expect(controller.count, 1);
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(originalState),
        true,
      );
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(updatedState),
        false,
      );
    });

    testWidgets('updates state if not current', (tester) async {
      WidgetsFlutterBinding.ensureInitialized();
      expect(controller.count, 0);

      routerDelegate.navigate(page, null, originalState);
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(originalState),
        false,
      );
      expect(controller.count, 1);

      // Try to update state to an identical copy of the original state.
      routerDelegate.updateStateIfChanged(duplicateOriginalState);
      expect(controller.count, 1);
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(originalState),
        false,
      );

      routerDelegate.updateStateIfChanged(updatedState);
      expect(controller.count, 2);
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(originalState),
        true,
      );
      expect(
        routerDelegate.currentConfiguration!.state!.hasChanges(updatedState),
        false,
      );
    });

    testWidgets('keeps track of history', (tester) async {
      WidgetsFlutterBinding.ensureInitialized();
      expect(controller.count, 0);
      expect(routerDelegate.currentConfigurationIndex, -1);

      routerDelegate.navigate(page, null, originalState);
      expect(routerDelegate.currentConfigurationIndex, 0);
      expect(controller.count, 1);

      routerDelegate.navigate('Page2', {'foo': 'bar'});
      expect(routerDelegate.currentConfigurationIndex, 1);
      final page2Config = routerDelegate.currentConfiguration!;
      final page2Index = routerDelegate.currentConfigurationIndex;

      routerDelegate.navigate('Page3', null, originalState);
      expect(routerDelegate.currentConfigurationIndex, 2);
      final page3Config = routerDelegate.currentConfiguration!;
      final page3Index = routerDelegate.currentConfigurationIndex;

      // Simulate the system navigator handling a back event. This should bring
      // us back to Page2.
      await routerDelegate.setNewRoutePath(page2Config);
      expect(routerDelegate.currentConfigurationIndex, page2Index);
      expect(routerDelegate.routes.length, 3);

      // Simulate the system navigator handling a forward event, bringing us
      // back to Page3.
      await routerDelegate.setNewRoutePath(page3Config);
      expect(routerDelegate.currentConfigurationIndex, page3Index);
      expect(routerDelegate.routes.length, 3);

      // Go back to Page2 in preparation for navigating to Page4, replacing the
      // entry for Page3 in the router's history.
      await routerDelegate.setNewRoutePath(page2Config);
      expect(routerDelegate.currentConfigurationIndex, page2Index);
      expect(routerDelegate.routes.length, 3);

      // Navigate to Page4, which will remove Page3 from the router's history.
      routerDelegate.navigate('Page4');
      expect(routerDelegate.currentConfigurationIndex, 2);
      expect(routerDelegate.routes.length, 3);

      // Navigate again to Page4, which should not change the router state.
      routerDelegate.navigateIfNotCurrent('Page4');
      expect(routerDelegate.currentConfigurationIndex, 2);
      expect(routerDelegate.routes.length, 3);

      // Update args for Page4, which should result in a new entry in the
      // history.
      routerDelegate.updateArgsIfChanged({'baz': 'bar'});
      expect(routerDelegate.currentConfigurationIndex, 3);
      expect(routerDelegate.routes.length, 4);
      final page4WithArgsIndex = routerDelegate.currentConfigurationIndex;
      final page4WithArgsConfig = routerDelegate.currentConfiguration!;

      // Update state for Page4, which should result in a new entry in the
      // history.
      routerDelegate.updateStateIfChanged(
        DevToolsNavigationState(
          kind: 'foo',
          state: {},
        ),
      );
      expect(routerDelegate.currentConfigurationIndex, 4);
      expect(routerDelegate.routes.length, 5);

      // Navigate back to Page4 with arguments.
      await routerDelegate.setNewRoutePath(page4WithArgsConfig);
      expect(routerDelegate.currentConfigurationIndex, page4WithArgsIndex);
      expect(routerDelegate.routes.length, 5);
    });
  });
}
