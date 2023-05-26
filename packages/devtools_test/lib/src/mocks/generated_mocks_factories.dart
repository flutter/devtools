// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import 'generated.mocks.dart';

MockPerformanceController createMockPerformanceControllerWithDefaults() {
  final controller = MockPerformanceController();
  final timelineEventsController = MockTimelineEventsController();
  final legacyTimelineEventsController = MockLegacyTimelineEventsController();
  final flutterFramesController = MockFlutterFramesController();
  when(controller.data).thenReturn(PerformanceData());
  when(controller.enhanceTracingController)
      .thenReturn(EnhanceTracingController());
  when(controller.offlinePerformanceData).thenReturn(null);
  when(controller.selectedFeatureTabIndex).thenReturn(0);
  when(controller.initialized).thenAnswer((_) => Future.value());

  // Stubs for Flutter Frames feature.
  when(controller.flutterFramesController).thenReturn(flutterFramesController);
  when(flutterFramesController.selectedFrame)
      .thenReturn(const FixedValueListenable<FlutterFrame?>(null));
  when(flutterFramesController.recordingFrames)
      .thenReturn(const FixedValueListenable<bool>(true));
  when(flutterFramesController.displayRefreshRate)
      .thenReturn(ValueNotifier<double>(60.0));

  // Stubs for Raster Stats feature.
  when(controller.rasterStatsController)
      .thenReturn(RasterStatsController(controller));

  // Stubs for Timeline Events feature.
  when(controller.timelineEventsController)
      .thenReturn(timelineEventsController);
  when(timelineEventsController.useLegacyTraceViewer)
      .thenReturn(ValueNotifier<bool>(true));
  when(timelineEventsController.legacyController)
      .thenReturn(legacyTimelineEventsController);
  when(timelineEventsController.status).thenReturn(
    ValueNotifier<EventsControllerStatus>(EventsControllerStatus.empty),
  );
  when(legacyTimelineEventsController.searchMatches)
      .thenReturn(const FixedValueListenable<List<TimelineEvent>>([]));
  when(legacyTimelineEventsController.searchInProgressNotifier)
      .thenReturn(const FixedValueListenable<bool>(false));
  when(legacyTimelineEventsController.matchIndex)
      .thenReturn(ValueNotifier<int>(0));

  return controller;
}

MockProgramExplorerController
    createMockProgramExplorerControllerWithDefaults() {
  final controller = MockProgramExplorerController();
  when(controller.initialized).thenReturn(ValueNotifier(true));
  when(controller.rootObjectNodes).thenReturn(ValueNotifier([]));
  when(controller.outlineNodes).thenReturn(ValueNotifier([]));
  when(controller.isLoadingOutline).thenReturn(ValueNotifier(false));
  when(controller.selectedNodeIndex).thenReturn(ValueNotifier(0));
  return controller;
}

MockCodeViewController createMockCodeViewControllerWithDefaults({
  ProgramExplorerController? programExplorerController,
}) {
  final codeViewController = MockCodeViewController();
  when(codeViewController.fileExplorerVisible).thenReturn(ValueNotifier(false));
  when(codeViewController.currentScriptRef).thenReturn(ValueNotifier(null));
  when(codeViewController.scriptLocation).thenReturn(ValueNotifier(null));
  when(codeViewController.currentParsedScript)
      .thenReturn(ValueNotifier<ParsedScript?>(null));
  when(codeViewController.searchMatches).thenReturn(ValueNotifier([]));
  when(codeViewController.activeSearchMatch).thenReturn(ValueNotifier(null));
  when(codeViewController.showFileOpener).thenReturn(ValueNotifier(false));
  when(codeViewController.showSearchInFileField)
      .thenReturn(ValueNotifier(false));
  when(codeViewController.searchInProgressNotifier)
      .thenReturn(const FixedValueListenable<bool>(false));
  when(codeViewController.matchIndex).thenReturn(ValueNotifier<int>(0));
  programExplorerController ??=
      createMockProgramExplorerControllerWithDefaults();
  when(codeViewController.programExplorerController).thenReturn(
    programExplorerController,
  );
  when(codeViewController.showProfileInformation).thenReturn(
    const FixedValueListenable(false),
  );
  when(codeViewController.showCodeCoverage).thenReturn(ValueNotifier(false));
  when(codeViewController.focusLine).thenReturn(ValueNotifier(-1));

  return codeViewController;
}

MockDebuggerController createMockDebuggerControllerWithDefaults({
  // ignore: avoid-dynamic, can be either a real or mock controller.
  dynamic codeViewController,
}) {
  assert(
    codeViewController is MockCodeViewController? ||
        codeViewController is CodeViewController?,
  );
  final debuggerController = MockDebuggerController();
  when(debuggerController.resuming).thenReturn(ValueNotifier(false));
  when(debuggerController.isSystemIsolate).thenReturn(false);

  when(debuggerController.selectedBreakpoint).thenReturn(ValueNotifier(null));
  when(debuggerController.stackFramesWithLocation)
      .thenReturn(ValueNotifier([]));
  when(debuggerController.selectedStackFrame).thenReturn(ValueNotifier(null));

  when(debuggerController.exceptionPauseMode)
      .thenReturn(ValueNotifier('Unhandled'));

  codeViewController ??= createMockCodeViewControllerWithDefaults();
  when(debuggerController.codeViewController).thenReturn(
    codeViewController,
  );

  return debuggerController;
}

MockVmServiceWrapper createMockVmServiceWrapperWithDefaults() {
  final service = MockVmServiceWrapper();
  // `then` is used.
  // ignore: discarded_futures
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

MockLoggingController createMockLoggingControllerWithDefaults({
  List<LogData> data = const [],
}) {
  final mockLoggingController = MockLoggingController();
  when(mockLoggingController.data).thenReturn(data);
  when(mockLoggingController.filteredData)
      .thenReturn(ListValueNotifier<LogData>(data));
  when(mockLoggingController.isFilterActive).thenReturn(false);
  when(mockLoggingController.selectedLog)
      .thenReturn(ValueNotifier<LogData?>(null));
  when(mockLoggingController.searchFieldFocusNode).thenReturn(FocusNode());
  when(mockLoggingController.searchTextFieldController)
      .thenReturn(SearchTextEditingController());
  when(mockLoggingController.searchMatches)
      .thenReturn(const FixedValueListenable(<LogData>[]));
  when(mockLoggingController.activeSearchMatch)
      .thenReturn(const FixedValueListenable<LogData?>(null));
  when(mockLoggingController.searchInProgressNotifier)
      .thenReturn(const FixedValueListenable(false));
  when(mockLoggingController.matchIndex).thenReturn(ValueNotifier<int>(0));
  return mockLoggingController;
}
