// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/simple_items.dart';
import '../../../shared/primitives/memory_timeline.dart';

class MemoryControlPaneController {
  MemoryControlPaneController(
    this.memoryTimeline,
    this.mode, {
    required this.exportData,
  }) : assert(
          mode == ControllerCreationMode.disconnected || memoryTimeline != null,
        );

  final ControllerCreationMode mode;
  final MemoryTimeline? memoryTimeline;
  final VoidCallback exportData;
  final ValueNotifier<bool> isChartVisible = preferences.memory.showChart;

  bool get isGcing => _gcing;
  bool _gcing = false;

  Future<void> gc() async {
    assert(mode == ControllerCreationMode.connected);
    assert(memoryTimeline != null);
    _gcing = true;
    try {
      await serviceConnection.serviceManager.service!.getAllocationProfile(
        (serviceConnection
            .serviceManager.isolateManager.selectedIsolate.value?.id)!,
        gc: true,
      );
      memoryTimeline!.addGCEvent();
      notificationService.push('Successfully garbage collected.');
    } finally {
      _gcing = false;
    }
  }
}
