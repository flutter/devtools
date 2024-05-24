// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';
import '../../../../shared/primitives/simple_items.dart';
import 'tracing_data.dart';

@visibleForTesting
enum Json {
  stateForIsolate,
  selection;
}

class TracingPaneController extends DisposableController
    with AutoDisposeControllerMixin, Serializable {
  TracingPaneController(
    this.mode, {
    this.stateForIsolate = const {},
    String? selectedIsolateId,
  });

  factory TracingPaneController.fromJson(Map<String, dynamic> json) {
    return TracingPaneController(
      ControllerCreationMode.offlineData,
      stateForIsolate: (json[Json.stateForIsolate.name] as Map).map(
        (key, value) => MapEntry(
          key,
          deserialize<TracingIsolateState>(value, TracingIsolateState.fromJson),
        ),
      ),
      selectedIsolateId: json[Json.selection.name] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      Json.selection.name: selection.value.isolate.id,
      Json.stateForIsolate.name: stateForIsolate,
    };
  }

  final ControllerCreationMode mode;

  /// Maps isolate IDs to their allocation tracing states.
  final Map<String, TracingIsolateState> stateForIsolate;

  /// The allocation tracing state for the currently selected isolate.
  ValueListenable<TracingIsolateState> get selection => _selection;
  final _selection = ValueNotifier<TracingIsolateState>(
    TracingIsolateState.empty(),
  );

  /// Set to `true` if the controller has not yet finished initializing.
  ValueListenable<bool> get initializing => _initializing;
  final _initializing = ValueNotifier<bool>(true);

  /// Set to `true` when `refresh()` has been called and allocation profiles
  /// are being updated, before then being set again to `false`.
  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

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
        _selection.value = TracingIsolateState.empty();
        return;
      }

      final isolateId = isolate.id!;
      var state = stateForIsolate[isolateId];
      if (state == null) {
        // TODO(bkonyi): we don't need to request this unless we've had a hot reload.
        // We generally need to rebuild this data if we've had a hot reload or
        // switched the currently selected isolate.
        state = TracingIsolateState(isolate: isolate);
        await state.initialize();
        stateForIsolate[isolateId] = state;
      }
      // Restore the previously applied filter for the isolate.
      textEditingController.text = state.currentFilter;
      _selection.value = state;
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
    await selection.value.refresh();
    _refreshing.value = false;
  }

  /// Refreshes the allocation profiles for the current isolate's traced classes.
  Future<void> clear() async {
    _refreshing.value = true;
    await selection.value.clear();
    _refreshing.value = false;
  }

  /// Enables or disables tracing of allocations of [cls] in the current
  /// isolate.
  Future<void> setAllocationTracingForClass(ClassRef cls, bool enabled) async {
    await selection.value.setAllocationTracingForClass(cls, enabled);
  }

  /// Updates the class filter criteria for the current isolate's allocation
  /// tracing state.
  void updateClassFilter(String value) {
    selection.value.updateClassFilter(value);
  }
}
