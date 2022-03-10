// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:core';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../primitives/auto_dispose.dart';
import '../primitives/message_bus.dart';
import '../primitives/utils.dart';
import '../shared/globals.dart';
import 'isolate_state.dart';
import 'service_extensions.dart' as extensions;
import 'vm_service_wrapper.dart';

class IsolateManager extends Disposer {
  final _isolateStates = <IsolateRef, IsolateState>{};
  VmServiceWrapper? _service;

  final StreamController<IsolateRef?> _isolateCreatedController =
      StreamController<IsolateRef?>.broadcast();
  final StreamController<IsolateRef?> _isolateExitedController =
      StreamController<IsolateRef?>.broadcast();

  ValueListenable<IsolateRef?> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate = ValueNotifier<IsolateRef?>(null);

  int _lastIsolateIndex = 0;
  final Map<String?, int> _isolateIndexMap = {};

  ValueListenable<List<IsolateRef>> get isolates => _isolates;
  final _isolates = ListValueNotifier(const <IsolateRef>[]);

  Stream<IsolateRef?> get onIsolateCreated => _isolateCreatedController.stream;

  Stream<IsolateRef?> get onIsolateExited => _isolateExitedController.stream;

  ValueListenable<IsolateRef?> get mainIsolate => _mainIsolate;
  final _mainIsolate = ValueNotifier<IsolateRef?>(null);

  final _isolateRunnableCompleters = <String?, Completer<void>>{};

  Future<void> init(List<IsolateRef> isolates) async {
    // Re-initialize isolates when VM developer mode is enabled/disabled to
    // display/hide system isolates.
    addAutoDisposeListener(preferences.vmDeveloperModeEnabled, () async {
      final vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;
      final vm = await serviceManager.service!.getVM();
      final isolates = [
        ...vm.isolates ?? <IsolateRef>[],
        if (vmDeveloperModeEnabled) ...vm.systemIsolates ?? <IsolateRef>[],
      ];
      if (selectedIsolate.value!.isSystemIsolate! && !vmDeveloperModeEnabled) {
        selectIsolate(_isolates.value.first);
      }
      await _initIsolates(isolates);
    });
    await _initIsolates(isolates);
  }

  IsolateState? get mainIsolateDebuggerState {
    return _mainIsolate.value != null
        ? _isolateStates[_mainIsolate.value!]
        : null;
  }

  IsolateState? isolateDebuggerState(IsolateRef? isolate) {
    return isolate != null ? _isolateStates[isolate] : null;
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

  Future<void> _initIsolates(List<IsolateRef> isolates) async {
    _clearIsolateStates();

    await Future.wait([
      for (final isolateRef in isolates) _registerIsolate(isolateRef),
    ]);

    // It is critical that the _serviceExtensionManager is already listening
    // for events indicating that new extension rpcs are registered before this
    // call otherwise there is a race condition where service extensions are not
    // described in the selectedIsolate or recieved as an event. It is ok if a
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
  }

  Future<void> _loadIsolateState(IsolateRef isolateRef) async {
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
      state.onIsolateLoaded(isolate);
    }
  }

  Future<void> _handleIsolateEvent(Event event) async {
    _sendToMessageBus(event);
    if (event.kind == EventKind.kIsolateRunnable) {
      final isolateRunnable = _isolateRunnableCompleters.putIfAbsent(
        event.isolate!.id,
        () => Completer<void>(),
      );
      isolateRunnable.complete();
    } else if (event.kind == EventKind.kIsolateStart &&
        !event.isolate!.isSystemIsolate!) {
      await _registerIsolate(event.isolate!);
      _isolateCreatedController.add(event.isolate);
      // TODO(jacobr): we assume the first isolate started is the main isolate
      // but that may not always be a safe assumption.
      _mainIsolate.value ??= event.isolate;

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
        _mainIsolate.value = null;
      }
      if (_selectedIsolate.value == event.isolate) {
        _selectedIsolate.value =
            _isolateStates.isEmpty ? null : _isolateStates.keys.first;
      }
      _isolateRunnableCompleters.remove(event.isolate!.id);
    }
  }

  void _sendToMessageBus(Event event) {
    messageBus.addEvent(BusEvent(
      'debugger',
      data: event,
    ));
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
    for (var isolateState in _isolateStates.values) {
      if (_selectedIsolate.value == null) {
        final isolate = await isolateState.isolate;
        if (service != _service) return null;
        for (String extensionName in isolate?.extensionRPCs ?? []) {
          if (extensions.isFlutterExtension(extensionName)) {
            return isolateState.isolateRef;
          }
        }
      }
    }

    final IsolateRef? ref =
        _isolateStates.keys.firstWhereOrNull((IsolateRef ref) {
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

  void _clearIsolateStates() {
    for (var isolateState in _isolateStates.values) {
      isolateState.dispose();
    }
    _isolateStates.clear();
    _isolates.clear();
  }

  void vmServiceOpened(VmServiceWrapper service) {
    _selectedIsolate.value = null;

    cancelStreamSubscriptions();
    _service = service;
    autoDisposeStreamSubscription(
        service.onIsolateEvent.listen(_handleIsolateEvent));
    autoDisposeStreamSubscription(
        service.onDebugEvent.listen(_handleDebugEvent));

    // We don't yet known the main isolate.
    _mainIsolate.value = null;
  }

  Future<Isolate?> getIsolateCached(IsolateRef isolateRef) {
    final isolateState =
        _isolateStates.putIfAbsent(isolateRef, () => IsolateState(isolateRef));
    return isolateState.isolate;
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
