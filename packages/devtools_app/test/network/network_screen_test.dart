// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/network/network_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late NetworkScreen screen;
  late FakeServiceManager fakeServiceManager;

  group('NetworkScreen', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier('network'))
          .thenReturn(ValueNotifier<int>(0));
      screen = const NetworkScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Network'), findsOneWidget);
    });
  });
}
