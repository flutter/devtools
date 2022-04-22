// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';

import 'generated.mocks.dart';

void mockIsFlutterApp(
  MockConnectedApp connectedApp, {
  bool isFlutterApp = true,
  bool isProfileBuild = false,
}) {
  when(connectedApp.isFlutterAppNow).thenReturn(isFlutterApp);
  when(connectedApp.isFlutterApp).thenAnswer((_) => Future.value(isFlutterApp));
  when(connectedApp.connectedAppInitialized).thenReturn(true);
  when(connectedApp.isDebugFlutterAppNow)
      .thenReturn(!isProfileBuild && isFlutterApp);
  when(connectedApp.isProfileBuildNow).thenReturn(isProfileBuild);
}

MockProgramExplorerController
    createMockProgramExplorerControllerWithDefaults() {
  final result = MockProgramExplorerController();

  when(result.initialized).thenReturn(ValueNotifier(true));
  when(result.rootObjectNodes).thenReturn(ValueNotifier([]));
  when(result.outlineNodes).thenReturn(ValueNotifier([]));
  when(result.outlineSelection).thenReturn(ValueNotifier(null));
  when(result.isLoadingOutline).thenReturn(ValueNotifier(false));

  return result;
}

MockDebuggerController createMockDebuggerControllerWithDefaults() {
  final debuggerController = MockDebuggerController();
  when(debuggerController.isPaused).thenReturn(ValueNotifier(false));
  when(debuggerController.resuming).thenReturn(ValueNotifier(false));
  when(debuggerController.breakpoints).thenReturn(ValueNotifier([]));
  when(debuggerController.isSystemIsolate).thenReturn(false);
  when(debuggerController.breakpointsWithLocation)
      .thenReturn(ValueNotifier([]));
  when(debuggerController.fileExplorerVisible).thenReturn(ValueNotifier(false));
  when(debuggerController.currentScriptRef).thenReturn(ValueNotifier(null));
  when(debuggerController.selectedBreakpoint).thenReturn(ValueNotifier(null));
  when(debuggerController.stackFramesWithLocation)
      .thenReturn(ValueNotifier([]));
  when(debuggerController.selectedStackFrame).thenReturn(ValueNotifier(null));
  when(debuggerController.hasTruncatedFrames).thenReturn(ValueNotifier(false));
  when(debuggerController.scriptLocation).thenReturn(ValueNotifier(null));
  when(debuggerController.exceptionPauseMode)
      .thenReturn(ValueNotifier('Unhandled'));
  when(debuggerController.variables).thenReturn(ValueNotifier([]));
  when(debuggerController.currentParsedScript)
      .thenReturn(ValueNotifier<ParsedScript?>(null));
  return debuggerController;
}
