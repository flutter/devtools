// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' hide Error;

// TODO(https://github.com/flutter/devtools/issues/6239): try to remove this.
@sealed
class IsolateState {
  IsolateState(this.isolateRef);

  final IsolateRef isolateRef;

  /// Returns null if only this instance of [IsolateState] is disposed.
  Future<Isolate?> get isolate => _isolateLoadCompleter.future;
  Completer<Isolate?> _isolateLoadCompleter = Completer();

  Future<void> waitForIsolateLoad() async => _isolateLoadCompleter;

  Isolate? get isolateNow => _isolateNow;
  Isolate? _isolateNow;

  RootInfo? rootInfo;

  ValueListenable<bool> get isPaused => _isPaused;
  final _isPaused = ValueNotifier<bool>(false);

  void handleIsolateLoad(Isolate isolate) {
    _isolateNow = isolate;

    _isPaused.value = isolate.pauseEvent != null &&
        isolate.pauseEvent!.kind != EventKind.kResume;

    rootInfo = RootInfo(_isolateNow!.rootLib?.uri);

    _isolateLoadCompleter.complete(isolate);
  }

  void dispose() {
    _isolateNow = null;
    if (!_isolateLoadCompleter.isCompleted) {
      _isolateLoadCompleter.complete(null);
    } else {
      _isolateLoadCompleter = Completer()..complete(null);
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

class RootInfo {
  RootInfo(this.library) : package = _libraryToPackage(library);

  final String? library;
  final String? package;

  static String? _libraryToPackage(String? library) {
    if (library == null) return null;
    final slashIndex = library.indexOf('/');
    if (slashIndex == -1) return library;
    return library.substring(0, slashIndex);
  }
}
