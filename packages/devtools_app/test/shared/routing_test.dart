// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/cupertino.dart';
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

  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    setGlobal(ServiceConnectionManager, FakeServiceManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    controller = TestController();
    navKey = GlobalKey<NavigatorState>();
    routerDelegate = DevToolsRouterDelegate(
      (p0, p1, p2, p3) => const CupertinoPage(child: SizedBox.shrink()),
      navKey,
    );
    controller.subscribeToRouterEvents(routerDelegate);
  });

  tearDown(() {
    controller.dispose();
  });

  group('Route state handler', () {
    test('gets basic router updates', () {
      expect(controller.count, 0);
      routerDelegate.navigate('Test');
      expect(controller.count, 1);
    });
  });
}
