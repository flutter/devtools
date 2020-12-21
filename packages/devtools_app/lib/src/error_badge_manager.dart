// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'auto_dispose.dart';
import 'globals.dart';
import 'service_extensions.dart' as extensions;
import 'vm_service_wrapper.dart';

class ErrorBadgeManager extends DisposableController
    with AutoDisposeControllerMixin {
  // TODO(kenz): populate this map with screens as support is added
  // (e.g. { LoggingScreen.id: ValueNotifier<int>(0) }
  final _activeErrorCounts = <String, ValueNotifier<int>>{};

  void vmServiceOpened(VmServiceWrapper service) {
    // Ensure structured errors are enabled.
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensions.structuredErrors.extension,
      true,
      true,
    );

    // Log Flutter extension events.
    autoDispose(service.onExtensionEvent.listen(_handleExtensionEvent));

    // Log stderr events.
    autoDispose(service.onStderrEvent.listen(_handleStdErr));
  }

  void _handleExtensionEvent(Event e) async {
    // TODO(kenz): handle Flutter.Error extension events.
  }

  void _handleStdErr(Event e) {
    // TODO(kenz): handle stderr events
  }

  ValueListenable<int> errorCountNotifier(String screenId) {
    return _activeErrorCounts[screenId] ?? const FixedValueListenable<int>(0);
  }

  void clearErrors(String screenId) {
    _activeErrorCounts[screenId]?.value = 0;
  }
}
