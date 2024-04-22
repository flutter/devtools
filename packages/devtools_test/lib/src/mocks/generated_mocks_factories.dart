// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import 'fake_isolate_manager.dart';
import 'fake_service_extension_manager.dart';
import 'generated.mocks.dart';

MockPerformanceController createMockPerformanceControllerWithDefaults() {
  final controller = MockPerformanceController();
  final timelineEventsController = MockTimelineEventsController();
  final flutterFramesController = MockFlutterFramesController();
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
      .thenReturn(ValueNotifier<double>(defaultRefreshRate));

  // Stubs for Raster Stats feature.
  when(controller.rasterStatsController)
      .thenReturn(RasterStatsController(controller));

  // Stubs for Timeline Events feature.
  when(controller.timelineEventsController)
      .thenReturn(timelineEventsController);
  when(timelineEventsController.status).thenReturn(
    ValueNotifier<EventsControllerStatus>(EventsControllerStatus.empty),
  );

  // Stubs for Rebuild Count feature
  when(controller.rebuildCountModel).thenReturn(RebuildCountModel());

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
  when(codeViewController.navigationInProgress).thenReturn(false);

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
  when(service.onStdoutEventWithHistorySafe).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onStderrEventWithHistorySafe).thenAnswer((_) {
    return const Stream.empty();
  });
  when(service.onExtensionEventWithHistorySafe).thenAnswer((_) {
    return const Stream.empty();
  });
  return service;
}

MockServiceConnectionManager createMockServiceConnectionWithDefaults() {
  final mockServiceConnection = MockServiceConnectionManager();
  final mockServiceManager = _createMockServiceManagerWithDefaults();
  when(mockServiceConnection.serviceManager).thenReturn(mockServiceManager);

  return mockServiceConnection;
}

MockServiceManager<VmServiceWrapper> _createMockServiceManagerWithDefaults() {
  final mockServiceManager = MockServiceManager<VmServiceWrapper>();

  final fakeIsolateManager = FakeIsolateManager();
  provideDummy<IsolateManager>(fakeIsolateManager);

  final fakeServiceExtensionManager = FakeServiceExtensionManager();
  provideDummy<ServiceExtensionManager>(fakeServiceExtensionManager);

  when(mockServiceManager.isolateManager).thenReturn(fakeIsolateManager);
  when(mockServiceManager.serviceExtensionManager)
      .thenReturn(fakeServiceExtensionManager);
  return mockServiceManager;
}

MockLoggingController createMockLoggingControllerWithDefaults({
  List<LogData> data = const [],
}) {
  provideDummy<ListValueNotifier<LogData>>(ListValueNotifier<LogData>(data));
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

Future<MockExtensionService> createMockExtensionServiceWithDefaults(
  List<DevToolsExtensionConfig> extensions,
) async {
  final mockExtensionService = MockExtensionService();
  // TODO(kenz): once static extension support is landed, de-duplicate these
  // extensions properly.
  final extensionsWithoutDuplicates = <DevToolsExtensionConfig>[];
  for (final ext in extensions) {
    if (extensionsWithoutDuplicates.containsWhere((e) => e.name == ext.name)) {
      continue;
    }
    extensionsWithoutDuplicates.add(ext);
  }
  when(mockExtensionService.availableExtensions)
      .thenReturn(ImmediateValueNotifier(extensionsWithoutDuplicates));

  final stubEnabledStates = <String, ValueNotifier<ExtensionEnabledState>>{};

  void computeVisibleExtensions() {
    final visible = <DevToolsExtensionConfig>[];
    for (final e in extensions) {
      final state = stubEnabledStates[e.name.toLowerCase()]!.value;
      if (state != ExtensionEnabledState.disabled) {
        visible.add(e);
      }
    }
    when(mockExtensionService.visibleExtensions)
        .thenReturn(ValueNotifier(visible));
  }

  for (final e in extensions) {
    stubEnabledStates[e.displayName] =
        ValueNotifier<ExtensionEnabledState>(ExtensionEnabledState.none);
    when(mockExtensionService.enabledStateListenable(e.name))
        .thenReturn(stubEnabledStates[e.displayName]!);
    when(mockExtensionService.enabledStateListenable(e.name.toLowerCase()))
        .thenReturn(stubEnabledStates[e.displayName]!);
    when(mockExtensionService.setExtensionEnabledState(e, enable: true))
        .thenAnswer((_) async {
      stubEnabledStates[e.displayName]!.value = ExtensionEnabledState.enabled;
      computeVisibleExtensions();
    });
    when(mockExtensionService.setExtensionEnabledState(e, enable: false))
        .thenAnswer((_) async {
      stubEnabledStates[e.name.toLowerCase()]!.value =
          ExtensionEnabledState.disabled;
      computeVisibleExtensions();
    });
  }
  computeVisibleExtensions();
  return mockExtensionService;
}
