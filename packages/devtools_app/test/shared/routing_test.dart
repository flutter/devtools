// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(bkonyi): add integration tests for navigation state.
// See https://github.com/flutter/devtools/issues/4902.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
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
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
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
    expect(routerDelegate.currentConfiguration!.params, args);
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
  });
}
