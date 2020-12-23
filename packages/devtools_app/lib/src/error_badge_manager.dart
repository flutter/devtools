// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'auto_dispose.dart';
import 'globals.dart';
import 'listenable.dart';
import 'logging/logging_screen.dart';
import 'network/network_screen.dart';
import 'service_extensions.dart' as extensions;
import 'vm_service_wrapper.dart';

class ErrorBadgeManager extends DisposableController
    with AutoDisposeControllerMixin {
  final _activeErrorCounts = <String, ValueNotifier<int>>{
    LoggingScreen.id: ValueNotifier<int>(0),
    NetworkScreen.id: ValueNotifier<int>(0),
  };

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
    // TODO(jacobr): badge inspector for appropriate errors.
    if (e.extensionKind == 'Flutter.Error') {
      incrementBadgeCount(LoggingScreen.id);
    }
  }

  void _handleStdErr(Event e) {
    incrementBadgeCount(LoggingScreen.id);
  }

  void incrementBadgeCount(String screenId) {
    final notifier = _errorCountNotifier(screenId);
    if (notifier == null) return;

    final currentCount = notifier.value;
    notifier.value = currentCount + 1;
  }

  ValueListenable<int> errorCountNotifier(String screenId) {
    return _errorCountNotifier(screenId) ?? const FixedValueListenable<int>(0);
  }

  ValueNotifier<int> _errorCountNotifier(String screenId) {
    return _activeErrorCounts[screenId];
  }

  void clearErrors(String screenId) {
    _activeErrorCounts[screenId]?.value = 0;
  }
}
