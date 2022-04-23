import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';

import 'generated.mocks.dart';

MockProgramExplorerController
    createMockProgramExplorerControllerWithDefaults() {
  final controller = MockProgramExplorerController();
  when(controller.initialized).thenReturn(ValueNotifier(true));
  when(controller.rootObjectNodes).thenReturn(ValueNotifier([]));
  when(controller.outlineNodes).thenReturn(ValueNotifier([]));
  when(controller.outlineSelection).thenReturn(ValueNotifier(null));
  when(controller.isLoadingOutline).thenReturn(ValueNotifier(false));
  return controller;
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
