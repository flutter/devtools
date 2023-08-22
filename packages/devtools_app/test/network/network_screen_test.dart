// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late NetworkScreen screen;
  late FakeServiceConnectionManager fakeServiceConnection;

  group('NetworkScreen', () {
    setUp(() {
      fakeServiceConnection = FakeServiceConnectionManager();
      when(fakeServiceConnection.serviceManager.connectedApp!.isDartWebAppNow)
          .thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());
      when(
        fakeServiceConnection.errorBadgeManager.errorCountNotifier('network'),
      ).thenReturn(ValueNotifier<int>(0));
      screen = NetworkScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Network'), findsOneWidget);
    });
  });
}
