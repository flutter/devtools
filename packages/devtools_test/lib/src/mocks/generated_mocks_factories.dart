// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';

import 'generated.mocks.dart';

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
