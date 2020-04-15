// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/flutter/debugger_screen.dart';
import 'package:devtools_app/src/flutter/common_widgets.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  DebuggerScreen screen;
  FakeServiceManager fakeServiceManager;

  group('DebuggerScreen', () {
    setUp(() async {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      screen = const DebuggerScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Debugger'), findsOneWidget);
    });

    testWidgets('builds disabled message when disabled for profile mode',
        (WidgetTester tester) async {
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(true);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(DebuggerScreenBody), findsNothing);
      expect(find.byType(DisabledForProfileBuildMessage), findsOneWidget);
    });

    testWidgets('has Console area', (WidgetTester tester) async {
      final debuggerController = MockDebuggerController();
      when(debuggerController.isPaused).thenReturn(ValueNotifier(false));
      when(debuggerController.breakpoints).thenReturn(ValueNotifier([]));
      when(debuggerController.scriptList)
          .thenReturn(ValueNotifier(ScriptList(scripts: [])));
      when(debuggerController.sortedScripts).thenReturn(ValueNotifier([]));
      when(debuggerController.currentStack).thenReturn(ValueNotifier(null));
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ));

      expect(find.text('Console'), findsOneWidget);

      expect(find.text('todo:'), findsOneWidget);
    });

    testWidgets('Scripts show items', (WidgetTester tester) async {
      final scripts = [ScriptRef(uri: 'package:/test/script.dart')];

      final debuggerController = MockDebuggerController();
      when(debuggerController.isPaused).thenReturn(ValueNotifier(false));
      when(debuggerController.breakpoints).thenReturn(ValueNotifier([]));
      when(debuggerController.scriptList)
          .thenReturn(ValueNotifier(ScriptList(scripts: scripts)));
      when(debuggerController.sortedScripts).thenReturn(ValueNotifier(scripts));
      when(debuggerController.currentStack).thenReturn(ValueNotifier(null));
      await tester.pumpWidget(wrapWithControllers(
        Builder(builder: screen.build),
        debugger: debuggerController,
      ));

      expect(find.text('Libraries'), findsOneWidget);

      // test for items in the libraries list
      expect(find.text(scripts.first.uri), findsOneWidget);
    });
  });
}
