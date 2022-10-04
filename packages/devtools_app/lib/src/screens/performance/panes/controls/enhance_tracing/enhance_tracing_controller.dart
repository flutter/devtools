// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../service/service_extensions.dart' as extensions;
import '../../../../../shared/globals.dart';
import 'enhance_tracing_model.dart';

final enhanceTracingExtensions = [
  extensions.profileWidgetBuilds,
  extensions.profileUserWidgetBuilds,
  extensions.profileRenderObjectLayouts,
  extensions.profileRenderObjectPaints,
];

class EnhanceTracingController extends DisposableController
    with AutoDisposeControllerMixin {
  final showMenuStreamController = StreamController<void>.broadcast();

  late EnhanceTracingState tracingState;

  final _extensionStates =
      Map<extensions.ToggleableServiceExtensionDescription, bool>.fromIterable(
    enhanceTracingExtensions,
    key: (ext) => ext,
    value: (_) => false,
  );

  void init() {
    for (int i = 0; i < enhanceTracingExtensions.length; i++) {
      final extension = enhanceTracingExtensions[i];
      final state = serviceManager.serviceExtensionManager
          .getServiceExtensionState(extension.extension);
      _extensionStates[extension] = state.value.enabled;
      // Listen for extension state changes so that we can update the value of
      // [_extensionStates] and [tracingState].
      addAutoDisposeListener(state, () {
        final value = state.value.enabled;
        _extensionStates[extension] = value;
        _updateTracingState();
      });
    }
    _updateTracingState();
  }

  void _updateTracingState() {
    final builds = _extensionStates[extensions.profileWidgetBuilds]! ||
        _extensionStates[extensions.profileUserWidgetBuilds]!;
    final layouts = _extensionStates[extensions.profileRenderObjectLayouts]!;
    final paints = _extensionStates[extensions.profileRenderObjectPaints]!;
    tracingState = EnhanceTracingState(
      builds: builds,
      layouts: layouts,
      paints: paints,
    );
  }

  void showEnhancedTracingMenu() {
    showMenuStreamController.add(null);
  }

  @override
  void dispose() {
    showMenuStreamController.close();
    super.dispose();
  }
}
