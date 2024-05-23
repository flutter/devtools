// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../devtools_app.dart';
import 'tracing_data.dart';

class TracingPaneController extends DisposableController
    with AutoDisposeControllerMixin {
  TracingPaneController(this.mode);

  final ControllerCreationMode mode;

  /// Set to `true` if the controller has not yet finished initializing.
  ValueListenable<bool> get initializing => _initializing;
  final _initializing = ValueNotifier<bool>(true);

  /// Set to `true` when `refresh()` has been called and allocation profiles
  /// are being updated, before then being set again to `false`.
  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  /// The allocation tracing state for the currently selected isolate.
  ValueListenable<TracingIsolateState> get stateForIsolate =>
      _stateForIsolateListenable;
  final _stateForIsolateListenable = ValueNotifier<TracingIsolateState>(
    TracingIsolateState.empty(),
  );

  final _stateForIsolate = <String, TracingIsolateState>{};

  /// The [TextEditingController] for the 'Class Filter' text field.
  final textEditingController = TextEditingController();

  bool _initialized = false;

  /// Initializes the controller if it is not initialized yet.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _initializing.value = true;

    Future<void> updateState() async {
      final isolate =
          serviceConnection.serviceManager.isolateManager.selectedIsolate.value;

      if (isolate == null) {
        _stateForIsolateListenable.value = TracingIsolateState.empty();
        return;
      }

      final isolateId = isolate.id!;
      var state = _stateForIsolate[isolateId];
      if (state == null) {
        // TODO(bkonyi): we don't need to request this unless we've had a hot reload.
        // We generally need to rebuild this data if we've had a hot reload or
        // switched the currently selected isolate.
        state = TracingIsolateState(isolate: isolate);
        await state.initialize();
        _stateForIsolate[isolateId] = state;
      }
      // Restore the previously applied filter for the isolate.
      textEditingController.text = state.currentFilter;
      _stateForIsolateListenable.value = state;
    }

    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.selectedIsolate,
      updateState,
    );

    await updateState();
    await refresh();

    _initializing.value = false;
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  /// Refreshes the allocation profiles for the current isolate's traced classes.
  Future<void> refresh() async {
    _refreshing.value = true;
    await stateForIsolate.value.refresh();
    _refreshing.value = false;
  }

  /// Refreshes the allocation profiles for the current isolate's traced classes.
  Future<void> clear() async {
    _refreshing.value = true;
    await stateForIsolate.value.clear();
    _refreshing.value = false;
  }

  /// Enables or disables tracing of allocations of [cls] in the current
  /// isolate.
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    await stateForIsolate.value.setAllocationTracingForClass(cls, enabled);
  }

  /// Updates the class filter criteria for the current isolate's allocation
  /// tracing state.
  void updateClassFilter(String value) {
    stateForIsolate.value.updateClassFilter(value);
  }
}
