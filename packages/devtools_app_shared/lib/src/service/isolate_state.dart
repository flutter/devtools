// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:core';

import 'package:devtools_shared/devtools_shared.dart';
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

    _isPaused.value =
        isolate.pauseEvent != null &&
        isolate.pauseEvent!.kind != EventKind.kResume;

    rootInfo = RootInfo(_isolateNow!.rootLib?.uri);

    _isolateLoadCompleter.complete(isolate);
  }

  void dispose() {
    _isolateNow = null;
    _isolateLoadCompleter.safeComplete(
      null,
      () => _isolateLoadCompleter = Completer()..complete(null),
    );
    _isPaused.dispose();
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

/// Information about the root library of an isolate of the connected app.
///
/// The root library is the library that contains the `main` function of the
/// isolate. See also [Isolate.rootLib].
class RootInfo {
  RootInfo(this.library) : package = _libraryToPackage(library);

  /// The URI of the root library, or `null` if it is unknown.
  ///
  /// This is not necessarily a `package:` URI. For example, the root library of
  /// a Dart CLI app started with `dart run` is a `file:` URI like
  /// `file:///app/bin/main.dart`.
  final String? library;

  /// The package that contains the root library, in the form `package:name`, or
  /// `null` if it is unknown.
  ///
  /// This is `null` if [library] is `null` or is not a `package:` URI (for
  /// example, a `file:` URI), since the name of the package is not known then.
  final String? package;

  static String? _libraryToPackage(String? library) {
    if (library == null || !library.startsWith('package:')) return null;
    final slashIndex = library.indexOf('/');
    if (slashIndex == -1) return library;
    return library.substring(0, slashIndex);
  }
}
