// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:mockito/annotations.dart';
import 'package:vm_service/vm_service.dart';

// See https://github.com/dart-lang/mockito/blob/master/NULL_SAFETY_README.md
// Run `sh tool/generate_code.sh` to regenerate mocks.
@GenerateMocks([
  ConnectedApp,
  ErrorBadgeManager,
  HeapSnapshotGraph,
  ProgramExplorerController,
  VmServiceWrapper,
  DebuggerController,
])
void main() {}
