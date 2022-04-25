// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  final fakeServiceManager = FakeServiceManager();
  final debuggerController = createMockDebuggerControllerWithDefaults();
  final scriptManager = MockScriptManagerLegacy();

  when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(debuggerController.isPaused).thenReturn(ValueNotifier<bool>(true));

  Future<void> pumpControls(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        FloatingDebuggerControls(),
        debugger: debuggerController,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('display as expected', (WidgetTester tester) async {
    await pumpControls(tester);
    final animatedOpacityFinder = find.byType(AnimatedOpacity);
    expect(animatedOpacityFinder, findsOneWidget);
    final animatedOpacity =
        animatedOpacityFinder.evaluate().first.widget as AnimatedOpacity;
    expect(animatedOpacity.opacity, equals(1.0));
    expect(
      find.text('Main isolate is paused in the debugger'),
      findsOneWidget,
    );
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.byTooltip('Step over'), findsOneWidget);
  });

  testWidgets('can resume', (WidgetTester tester) async {
    bool didResume = false;
    Future<Success> resume() {
      didResume = true;
      return Future.value(Success());
    }

    when(debuggerController.resume()).thenAnswer((_) => resume());
    await pumpControls(tester);
    expect(didResume, isFalse);
    await tester.tap(find.byTooltip('Resume'));
    await tester.pumpAndSettle();
    expect(didResume, isTrue);
  });

  testWidgets('can step over', (WidgetTester tester) async {
    bool didStep = false;
    Future<Success> stepOver() {
      didStep = true;
      return Future.value(Success());
    }

    when(debuggerController.stepOver()).thenAnswer((_) => stepOver());
    await pumpControls(tester);
    expect(didStep, isFalse);
    await tester.tap(find.byTooltip('Step over'));
    await tester.pumpAndSettle();
    expect(didStep, isTrue);
  });

  testWidgets('are hidden when app is not paused', (WidgetTester tester) async {
    when(debuggerController.isPaused).thenReturn(ValueNotifier<bool>(false));
    await pumpControls(tester);
    final animatedOpacityFinder = find.byType(AnimatedOpacity);
    expect(animatedOpacityFinder, findsOneWidget);
    final animatedOpacity =
        animatedOpacityFinder.evaluate().first.widget as AnimatedOpacity;
    expect(animatedOpacity.opacity, equals(0.0));
  });
}
