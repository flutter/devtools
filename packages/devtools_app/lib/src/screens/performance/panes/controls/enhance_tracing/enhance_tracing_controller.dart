// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../service/service_extensions.dart' as extensions;
import '../../../../../shared/globals.dart';

final enhanceTracingExtensions = [
  extensions.profileWidgetBuilds,
  extensions.profileUserWidgetBuilds,
  extensions.profileRenderObjectLayouts,
  extensions.profileRenderObjectPaints,
];

class EnhanceTracingController extends DisposableController
    with AutoDisposeControllerMixin {
  ValueListenable<bool> get tracingEnhanced => _tracingEnhanced;

  final _tracingEnhanced = ValueNotifier<bool>(false);

  final showMenuStreamController = StreamController<void>();

  final _extensionStates =
      Map<extensions.ToggleableServiceExtensionDescription, bool>.fromIterable(
    enhanceTracingExtensions,
    key: (ext) => ext,
    value: (_) => false,
  );

  void init() {
    bool _isTracingEnhanced() {
      for (final state in _extensionStates.values) {
        if (state) {
          return true;
        }
      }
      return false;
    }

    for (int i = 0; i < enhanceTracingExtensions.length; i++) {
      final extension = enhanceTracingExtensions[i];
      final state = serviceManager.serviceExtensionManager
          .getServiceExtensionState(extension.extension);
      _extensionStates[extension] = state.value.enabled;
      // Listen for extension state changes so that we can update the value of
      // [_tracingEnhanced].
      addAutoDisposeListener(state, () {
        final value = state.value.enabled;
        _extensionStates[extension] = value;
        _tracingEnhanced.value = _isTracingEnhanced();
      });
    }
    _tracingEnhanced.value = _isTracingEnhanced();
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
