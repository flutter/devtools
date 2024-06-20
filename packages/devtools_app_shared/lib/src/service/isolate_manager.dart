// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:dds_service_extensions/dds_service_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../utils/auto_dispose.dart';
import '../utils/list.dart';
import '../utils/utils.dart';
import 'isolate_state.dart';
import 'service_extensions.dart' as extensions;

final _log = Logger('isolate_manager');

@visibleForTesting
base mixin TestIsolateManager implements IsolateManager {}

final class IsolateManager with DisposerMixin {
  final _isolateStates = <IsolateRef, IsolateState>{};

  /// The amount of time we will wait for the main isolate to become non-null
  /// when calling [waitForMainIsolateState].
  static const _waitForMainIsolateStateTimeout = Duration(seconds: 3);

  /// Signifies whether the main isolate should be selected if it is started.
  ///
  /// This is used to make sure the the main isolate remains selected after
  /// a hot restart.
  bool _shouldReselectMainIsolate = false;

  VmService? _service;

  final _isolateCreatedController = StreamController<IsolateRef?>.broadcast();
  final _isolateExitedController = StreamController<IsolateRef?>.broadcast();

  ValueListenable<IsolateRef?> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate = ValueNotifier<IsolateRef?>(null);

  int _lastIsolateIndex = 0;
  final _isolateIndexMap = <String?, int>{};

  ValueListenable<List<IsolateRef>> get isolates => _isolates;
  final _isolates = ListValueNotifier(const <IsolateRef>[]);

  ValueListenable<IsolateRef?> get mainIsolate => _mainIsolate;
  final _mainIsolate = ValueNotifier<IsolateRef?>(null);

  final _isolateRunnableCompleters = <String?, Completer<void>>{};

  // TODO(https://github.com/flutter/flutter/issues/134470): Track hot-restarts
  // triggered by other clients.
  bool hotRestartInProgress = false;

  Future<void> init(List<IsolateRef> isolates) async {
    await initIsolates(isolates);
  }

  IsolateState? get mainIsolateState {
    return _mainIsolate.value != null
        ? _isolateStates[_mainIsolate.value!]
        : null;
  }

  Future<IsolateState?> waitForMainIsolateState() async {
    final mainIsolateRef = await whenValueNonNull<IsolateRef?>(
      mainIsolate,
      timeout: _waitForMainIsolateStateTimeout,
    );
    if (mainIsolateRef == null) return null;
    final state = mainIsolateState;
    await state?.waitForIsolateLoad();
    return state;
  }

  /// Return a unique, monotonically increasing number for this Isolate.
  int? isolateIndex(IsolateRef isolateRef) {
    if (!_isolateIndexMap.containsKey(isolateRef.id)) {
      _isolateIndexMap[isolateRef.id] = ++_lastIsolateIndex;
    }
    return _isolateIndexMap[isolateRef.id];
  }

  void selectIsolate(IsolateRef? isolateRef) {
    _setSelectedIsolate(isolateRef);
  }

  @protected
  Future<void> initIsolates(List<IsolateRef> isolates) async {
    _clearIsolateStates();

    await Future.wait([
      for (final isolateRef in isolates) _registerIsolate(isolateRef),
    ]);

    // It is critical that the _serviceExtensionManager is already listening
    // for events indicating that new extension rpcs are registered before this
    // call otherwise there is a race condition where service extensions are not
    // described in the selectedIsolate or received as an event. It is ok if a
    // service extension is included in both places as duplicate extensions are
    // handled gracefully.
    await _initSelectedIsolate();
  }

  Future<void> _registerIsolate(IsolateRef isolateRef) async {
    assert(!_isolateStates.containsKey(isolateRef));
    _isolateStates[isolateRef] = IsolateState(isolateRef);
    _isolates.add(isolateRef);
    isolateIndex(isolateRef);
    await _loadIsolateState(isolateRef);
    // If the flag pause-breakpoints-on-start was successfully set, then each
    // new isolate will start paused. Therefore resume it (unless it is the
    // current isolate, in which case the breakpoint manager will resume it
    // after setting breakpoints):
    final selectedIsolateId = selectedIsolate.value?.id;
    if (selectedIsolateId != null && selectedIsolateId != isolateRef.id) {
      await resumeIsolate(isolateRef);
    }
  }

  Future<void> _loadIsolateState(IsolateRef isolateRef) async {
    try {
      final service = _service;
      var isolate = await _service!.getIsolate(isolateRef.id!);
      if (isolate.runnable == false) {
        final isolateRunnableCompleter = _isolateRunnableCompleters.putIfAbsent(
          isolate.id,
          () => Completer<void>(),
        );
        if (!isolateRunnableCompleter.isCompleted) {
          await isolateRunnableCompleter.future;
          isolate = await _service!.getIsolate(isolate.id!);
        }
      }
      if (service != _service) return;
      final state = _isolateStates[isolateRef];
      if (state != null) {
        // Isolate might have already been closed.
        state.handleIsolateLoad(isolate);
      }
    } on SentinelException catch (_) {
      // Isolate doesn't exist anymore, nothing to do.
      _log.info(
        'isolateRef($isolateRef) ceased to exist while loading isolate state',
      );
    }
  }

  Future<void> _handleIsolateEvent(Event event) async {
    if (event.kind == EventKind.kIsolateRunnable) {
      final isolateRunnable = _isolateRunnableCompleters.putIfAbsent(
        event.isolate!.id,
        () => Completer<void>(),
      );
      isolateRunnable.complete();
      if (hotRestartInProgress) {
        hotRestartInProgress = false;
      }
    } else if (event.kind == EventKind.kIsolateStart &&
        !event.isolate!.isSystemIsolate!) {
      await _registerIsolate(event.isolate!);
      _isolateCreatedController.add(event.isolate);
      // TODO(jacobr): we assume the first isolate started is the main isolate
      // but that may not always be a safe assumption.
      if (_mainIsolate.value == null) {
        _mainIsolate.value = event.isolate;
        if (_shouldReselectMainIsolate) {
          // Assume the main isolate has come back up after a hot restart, so
          // select it.
          _shouldReselectMainIsolate = false;
          _setSelectedIsolate(event.isolate);
        }
      }

      if (_selectedIsolate.value == null) {
        _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kServiceExtensionAdded) {
      // Check to see if there is a new isolate.
      if (_selectedIsolate.value == null &&
          extensions.isFlutterExtension(event.extensionRPC!)) {
        _setSelectedIsolate(event.isolate);
      }
    } else if (event.kind == EventKind.kIsolateExit) {
      _isolateStates.remove(event.isolate)?.dispose();
      if (event.isolate != null) _isolates.remove(event.isolate!);
      _isolateExitedController.add(event.isolate);
      if (_mainIsolate.value == event.isolate) {
        if (_selectedIsolate.value == _mainIsolate.value) {
          // If the main isolate was selected and exits, then assume that a hot
          // restart is happening. So reselect when the main isolate comes back.
          _shouldReselectMainIsolate = true;
        }
        _mainIsolate.value = null;
      }
      if (_selectedIsolate.value == event.isolate) {
        _selectedIsolate.value = _isolateStates.keys.firstOrNull;
      }
      _isolateRunnableCompleters.remove(event.isolate!.id);
    }
  }

  Future<void> _initSelectedIsolate() async {
    if (_isolateStates.isEmpty) {
      return;
    }
    _mainIsolate.value = null;
    final service = _service;
    final mainIsolate = await _computeMainIsolate();
    if (service != _service) return;
    _mainIsolate.value = mainIsolate;
    _setSelectedIsolate(_mainIsolate.value);
  }

  Future<IsolateRef?> _computeMainIsolate() async {
    if (_isolateStates.isEmpty) return null;

    final service = _service;
    for (final isolateState in _isolateStates.values) {
      if (_selectedIsolate.value == null) {
        final isolate = await isolateState.isolate;
        if (service != _service) return null;
        for (final extensionName in isolate?.extensionRPCs ?? <String>[]) {
          if (extensions.isFlutterExtension(extensionName)) {
            return isolateState.isolateRef;
          }
        }
      }
    }

    final ref = _isolateStates.keys.firstWhereOrNull((IsolateRef ref) {
      // 'foo.dart:main()'
      return ref.name!.contains(':main(');
    });

    return ref ?? _isolateStates.keys.first;
  }

  void _setSelectedIsolate(IsolateRef? ref) {
    _selectedIsolate.value = ref;
  }

  void handleVmServiceClosed() {
    cancelStreamSubscriptions();
    _selectedIsolate.value = null;
    _service = null;
    _lastIsolateIndex = 0;
    _setSelectedIsolate(null);
    _isolateIndexMap.clear();
    _clearIsolateStates();
    _mainIsolate.value = null;
    _isolateRunnableCompleters.clear();
  }

  /// Resumes the isolate by calling [DdsExtension.readyToResume].
  ///
  /// CAUTION: This should only be used for a tool-initiated resume, not a user-
  /// initiated resume. See:
  ///  https://github.com/dart-lang/sdk/commit/5536951738ba599d96e075b7140e52b28e233
  Future<void> resumeIsolate(IsolateRef isolateRef) async {
    if (isolateRef.id == null || _service == null) return;
    final isolateId = isolateRef.id!;
    try {
      await _readyToResume(isolateId);
    } catch (error) {
      _log.warning(error);
    }
  }

  Future<void> _readyToResume(String isolateId) async {
    final service = _service!;
    try {
      await service.readyToResume(isolateId);
    } on UnimplementedError {
      // Fallback to a regular resume if the DDS version doesn't support
      // `readyToResume`:
      await service.resume(isolateId);
    }
  }

  void _clearIsolateStates() {
    for (final isolateState in _isolateStates.values) {
      isolateState.dispose();
    }
    _isolateStates.clear();
    _isolates.clear();
  }

  void vmServiceOpened(VmService service) {
    _selectedIsolate.value = null;

    cancelStreamSubscriptions();
    _service = service;
    autoDisposeStreamSubscription(
      service.onIsolateEvent.listen(_handleIsolateEvent),
    );
    autoDisposeStreamSubscription(
      service.onDebugEvent.listen(_handleDebugEvent),
    );

    // We don't know the main isolate yet.
    _mainIsolate.value = null;
  }

  IsolateState isolateState(IsolateRef isolateRef) {
    return _isolateStates.putIfAbsent(
      isolateRef,
      () => IsolateState(isolateRef),
    );
  }

  void _handleDebugEvent(Event event) {
    final isolate = event.isolate;
    if (isolate == null) return;
    final isolateState = _isolateStates[isolate];
    if (isolateState == null) {
      return;
    }

    isolateState.handleDebugEvent(event.kind);
  }
}
