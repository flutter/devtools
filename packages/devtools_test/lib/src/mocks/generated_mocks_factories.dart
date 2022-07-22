// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import 'generated.mocks.dart';

MockPerformanceController createMockPerformanceControllerWithDefaults() {
  final controller = MockPerformanceController();
  when(controller.data).thenReturn(PerformanceData());
  when(controller.searchMatches)
      .thenReturn(const FixedValueListenable<List<TimelineEvent>>([]));
  when(controller.searchInProgressNotifier)
      .thenReturn(const FixedValueListenable<bool>(false));
  when(controller.matchIndex).thenReturn(ValueNotifier<int>(0));
  when(controller.rasterMetricsController)
      .thenReturn(RasterMetricsController());
  when(controller.selectedFrame)
      .thenReturn(const FixedValueListenable<FlutterFrame?>(null));
  when(controller.displayRefreshRate).thenReturn(ValueNotifier<double>(60.0));
  return controller;
}

MockProgramExplorerController
    createMockProgramExplorerControllerWithDefaults() {
  final controller = MockProgramExplorerController();
  when(controller.initialized).thenReturn(ValueNotifier(true));
  when(controller.rootObjectNodes).thenReturn(ValueNotifier([]));
  when(controller.outlineNodes).thenReturn(ValueNotifier([]));
  when(controller.outlineSelection).thenReturn(ValueNotifier(null));
  when(controller.isLoadingOutline).thenReturn(ValueNotifier(false));
  when(controller.selectedNodeIndex).thenReturn(ValueNotifier(0));
  return controller;
}

MockDebuggerController createMockDebuggerControllerWithDefaults({
  MockProgramExplorerController? mockProgramExplorerController,
}) {
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
  mockProgramExplorerController ??=
      createMockProgramExplorerControllerWithDefaults();
  when(debuggerController.programExplorerController).thenReturn(
    mockProgramExplorerController,
  );
  return debuggerController;
}

MockVmServiceWrapper createMockVmServiceWrapperWithDefaults() {
  final service = MockVmServiceWrapper();
  when(service.getFlagList()).thenAnswer((_) async => FlagList(flags: []));
  when(service.onDebugEvent).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onVMEvent).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onIsolateEvent).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onStdoutEvent).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onStderrEvent).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onStdoutEventWithHistory).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onStderrEventWithHistory).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onExtensionEventWithHistory).thenAnswer((_) {
    return const Stream.empty();
  });
  return service;
}
