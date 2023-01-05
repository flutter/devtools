// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

class IsolateState {
  IsolateState(this.isolateRef);

  /// The value is guaranteed to be non-null after [waitForIsolateToLoad]
  /// is invoked.
  ValueListenable<bool?> get isPaused => _isPaused;

  final IsolateRef isolateRef;

  /// The isolate is null if only this instance is disposed.
  Future<Isolate?> get isolate => _completer.future;
  Completer<Isolate?> _completer = Completer();

  Isolate? get isolateNow => _isolateNow;
  Isolate? _isolateNow;

  /// Paused is null until we know whether the isolate is paused or not.
  final _isPaused = ValueNotifier<bool?>(null);

  void handleIsolateLoad(Isolate isolate) {
    _isolateNow = isolate;
    _completer.complete(isolate);
    _isPaused.value ??= isolate.pauseEvent != null &&
        isolate.pauseEvent!.kind != EventKind.kResume;
  }

  Future<void> waitForIsolateToLoad() async {
    await _completer.future;
  }

  void dispose() {
    _isolateNow = null;
    if (!_completer.isCompleted) {
      _completer.complete(null);
    } else {
      _completer = Completer()..complete(null);
    }
  }

  void handleDebugEvent(String? kind) {
    switch (kind) {
      case EventKind.kResume:
        _isPaused.value = false;
        break;
      case EventKind.kPauseStart:
      case EventKind.kPauseExit:
      case EventKind.kPauseBreakpoint:
      case EventKind.kPauseInterrupted:
      case EventKind.kPauseException:
      case EventKind.kPausePostRequest:
        _isPaused.value = true;
        break;
    }
  }
}
