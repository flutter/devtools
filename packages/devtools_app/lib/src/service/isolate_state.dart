// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

class IsolateState {
  IsolateState(this.isolateRef);

  final IsolateRef isolateRef;

  /// Returns null if only this instance of [IsolateState] is disposed.
  Future<Isolate?> get isolate => _completer.future;
  Completer<Isolate?> _completer = Completer();

  Isolate? get isolateNow => _isolateNow;
  Isolate? _isolateNow;

  ValueListenable<bool> get isPaused => _isPaused;
  final _isPaused = ValueNotifier<bool>(false);

  void handleIsolateLoad(Isolate isolate) {
    _isolateNow = isolate;
    _completer.complete(isolate);
    _isPaused.value = isolate.pauseEvent != null &&
        isolate.pauseEvent!.kind != EventKind.kResume;
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
