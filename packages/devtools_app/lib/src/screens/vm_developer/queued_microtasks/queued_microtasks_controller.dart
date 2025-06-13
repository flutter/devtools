// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../../shared/utils/future_work_tracker.dart';

enum QueuedMicrotasksControllerStatus { empty, refreshing, ready }

class QueuedMicrotasksController extends DisposableController
    with AutoDisposeControllerMixin {
  QueuedMicrotasksController() {
    addAutoDisposeListener(_refreshWorkTracker.active, () {
      final active = _refreshWorkTracker.active.value;
      if (active) {
        _status.value = QueuedMicrotasksControllerStatus.refreshing;
      } else {
        _status.value = QueuedMicrotasksControllerStatus.ready;
      }
    });
  }

  ValueListenable<QueuedMicrotasksControllerStatus> get status => _status;
  final _status = ValueNotifier<QueuedMicrotasksControllerStatus>(
    QueuedMicrotasksControllerStatus.empty,
  );

  ValueListenable<QueuedMicrotasks?> get queuedMicrotasks => _queuedMicrotasks;
  final _queuedMicrotasks = ValueNotifier<QueuedMicrotasks?>(null);

  ValueListenable<Microtask?> get selectedMicrotask => _selectedMicrotask;
  final _selectedMicrotask = ValueNotifier<Microtask?>(null);

  final _refreshWorkTracker = FutureWorkTracker();

  Future<void> refresh() => _refreshWorkTracker.track(() async {
    _selectedMicrotask.value = null;

    final isolateId = serviceConnection
        .serviceManager
        .isolateManager
        .selectedIsolate
        .value!
        .id!;
    final queuedMicrotasks = await serviceConnection.serviceManager.service!
        .getQueuedMicrotasks(isolateId);
    _queuedMicrotasks.value = queuedMicrotasks;

    return;
  });

  void setSelectedMicrotask(Microtask? microtask) {
    _selectedMicrotask.value = microtask;
  }

  @override
  void dispose() {
    _status.dispose();
    _queuedMicrotasks.dispose();
    _selectedMicrotask.dispose();
    _refreshWorkTracker
      ..clear()
      ..dispose();
    super.dispose();
  }
}
