// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:dtd/dtd.dart';
import 'package:mockito/annotations.dart';
import 'package:vm_service/vm_service.dart';

// See https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md
// Run `dt generate-code` to regenerate mocks.
@GenerateNiceMocks([
  MockSpec<ConnectedApp>(),
  MockSpec<DebuggerController>(),
  MockSpec<EnhanceTracingController>(),
  MockSpec<ErrorBadgeManager>(),
  MockSpec<FrameAnalysis>(),
  MockSpec<FramePhase>(),
  MockSpec<HeapSnapshotGraph>(),
  MockSpec<InspectorController>(),
  MockSpec<PerformanceController>(),
  MockSpec<FlutterFramesController>(),
  MockSpec<TimelineEventsController>(),
  MockSpec<LoggingController>(),
  MockSpec<ProgramExplorerController>(),
  MockSpec<ScriptManager>(),
  MockSpec<ServiceConnectionManager>(),
  MockSpec<ServiceManager>(),
  MockSpec<VmService>(),
  MockSpec<VmServiceWrapper>(),
  MockSpec<InspectorObjectGroupBase>(),
  MockSpec<VmObject>(),
  MockSpec<ClassObject>(),
  MockSpec<CodeObject>(),
  MockSpec<FieldObject>(),
  MockSpec<FuncObject>(),
  MockSpec<ScriptObject>(),
  MockSpec<LibraryObject>(),
  MockSpec<ObjectPoolObject>(),
  MockSpec<ICDataObject>(),
  MockSpec<SubtypeTestCacheObject>(),
  MockSpec<CodeViewController>(),
  MockSpec<BreakpointManager>(),
  MockSpec<EvalService>(),
  MockSpec<BannerMessagesController>(),
  MockSpec<Isolate>(),
  MockSpec<IsolateState>(),
  MockSpec<Obj>(),
  MockSpec<VM>(),
  MockSpec<EditorClient>(),
  MockSpec<PerfettoTrackDescriptorEvent>(),
  MockSpec<PerfettoTrackEvent>(),
  MockSpec<DTDManager>(),
  MockSpec<DartToolingDaemon>(),
  MockSpec<DTDToolsController>(),
])
void main() {}
