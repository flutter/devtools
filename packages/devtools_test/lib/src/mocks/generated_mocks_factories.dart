// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
