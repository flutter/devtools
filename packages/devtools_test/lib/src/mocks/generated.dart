// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:devtools_app/devtools_app.dart';
import 'package:mockito/annotations.dart';
import 'package:vm_service/vm_service.dart';

// See https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md
// Run `sh tool/generate_code.sh` to regenerate mocks.
@GenerateNiceMocks(
  [
    MockSpec<ConnectedApp>(),
    MockSpec<DebuggerController>(),
    MockSpec<EnhanceTracingController>(),
    MockSpec<ErrorBadgeManager>(),
    MockSpec<FrameAnalysis>(),
    MockSpec<FramePhase>(),
    MockSpec<HeapSnapshotGraph>(),
    MockSpec<InspectorController>(),
    MockSpec<PerformanceController>(),
    MockSpec<ProgramExplorerController>(),
    MockSpec<ScriptManager>(),
    MockSpec<ServiceConnectionManager>(),
    MockSpec<VmService>(),
    MockSpec<VmServiceWrapper>(),
    MockSpec<ObjectGroupBase>(),
    MockSpec<VmObject>(),
    MockSpec<ClassObject>(),
    MockSpec<CodeObject>(),
    MockSpec<FieldObject>(),
    MockSpec<FuncObject>(),
    MockSpec<ScriptObject>(),
    MockSpec<LibraryObject>(),
    MockSpec<ui.Image>(),
    MockSpec<CodeViewController>(),
    MockSpec<BreakpointManager>(),
  ],
)
void main() {}
