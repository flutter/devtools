// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

class IsolateState {
  IsolateState(this.isolateRef);

  ValueListenable<bool> get isPaused => _isPaused;

  final IsolateRef isolateRef;

  Future<Isolate> get isolate => _isolate.future;
  Completer<Isolate> _isolate = Completer();

  Isolate get isolateNow => _isolateNow;
  Isolate _isolateNow;

  /// Paused is null until we know whether the isolate is paused or not.
  final _isPaused = ValueNotifier<bool>(null);

  void onIsolateLoaded(Isolate isolate) {
    _isolateNow = isolate;
    _isolate.complete(isolate);
    if (_isPaused.value == null) {
      if (isolate.pauseEvent != null &&
          isolate.pauseEvent.kind != EventKind.kResume) {
        _isPaused.value = true;
      } else {
        _isPaused.value = false;
      }
    }
  }

  void dispose() {
    _isolateNow = null;
    if (!_isolate.isCompleted) {
      _isolate.complete(null);
    } else {
      _isolate = Completer()..complete(null);
    }
  }

  void pause() => _isPaused.value = true;

  void resume() => _isPaused.value = false;
}
