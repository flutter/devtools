// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../screens/inspector/inspector_screen.dart';
import '../../screens/logging/logging_screen.dart';
import '../../screens/network/network_screen.dart';
import '../../screens/performance/performance_screen.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../service/vm_service_wrapper.dart';
import '../globals.dart';
import '../primitives/listenable.dart';

/// Manages error badge counts for DevTools screen tabs.
///
/// This is a generic counter that tracks unread error counts per screen.
/// Screen-specific error tracking logic (e.g., detailed error objects for the
/// Inspector screen) should live in the respective screen controllers.
class ErrorBadgeManager extends DisposableController
    with AutoDisposeControllerMixin {
  final _activeErrorCounts = <String, ValueNotifier<int>>{
    InspectorScreen.id: ValueNotifier<int>(0),
    PerformanceScreen.id: ValueNotifier<int>(0),
    NetworkScreen.id: ValueNotifier<int>(0),
  };

  /// Screen ids whose unread badge count is owned by the screen controller.
  ///
  /// For these screens, [clearErrorCount] is a no-op so navigating to the tab
  /// (see scaffold) does not drop the unread badge. Controllers should update
  /// the count via [incrementBadgeCount], [decrementBadgeCount], and
  /// [resetErrorCount] instead.
  final _managedErrorCounts = <String>{};

  void vmServiceOpened(VmServiceWrapper service) {
    // Ensure structured errors are enabled.
    unawaited(
      serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            extensions.structuredErrors.extension,
            enabled: true,
            value: true,
          ),
    );

    // Log Flutter extension events.
    autoDisposeStreamSubscription(
      service.onExtensionEventWithHistorySafe.listen(_handleExtensionEvent),
    );

    // Log stderr events.
    autoDisposeStreamSubscription(
      service.onStderrEventWithHistorySafe.listen(_handleStdErr),
    );
  }

  void _handleExtensionEvent(Event e) {
    if (e.extensionKind == FlutterEvent.error) {
      incrementBadgeCount(LoggingScreen.id);
    }
  }

  void _handleStdErr(Event _) {
    incrementBadgeCount(LoggingScreen.id);
  }

  /// Marks [screenId] as managing its own unread badge count.
  ///
  /// After this is called, [clearErrorCount] will not reset the badge for
  /// [screenId] (preserving unread state across tab switches).
  void manageErrorCount(String screenId) {
    _managedErrorCounts.add(screenId);
  }

  void incrementBadgeCount(String screenId) {
    final notifier = _errorCountNotifier(screenId);
    if (notifier == null) return;

    notifier.value = notifier.value + 1;
  }

  void decrementBadgeCount(String screenId) {
    final notifier = _errorCountNotifier(screenId);
    if (notifier == null) return;
    if (notifier.value == 0) return;
    notifier.value = notifier.value - 1;
  }

  ValueListenable<int> errorCountNotifier(String screenId) {
    return _errorCountNotifier(screenId) ?? const FixedValueListenable<int>(0);
  }

  ValueNotifier<int>? _errorCountNotifier(String screenId) {
    return _activeErrorCounts[screenId];
  }

  /// Clears the badge count for [screenId], unless it is [manageErrorCount]d.
  void clearErrorCount(String screenId) {
    if (_managedErrorCounts.contains(screenId)) return;
    _activeErrorCounts[screenId]?.value = 0;
  }

  /// Unconditionally resets the badge count for [screenId].
  ///
  /// Use from screen controllers that call [manageErrorCount] when they need
  /// to clear their own unread state (e.g. on hot restart).
  void resetErrorCount(String screenId) {
    _activeErrorCounts[screenId]?.value = 0;
  }
}

class DevToolsError {
  DevToolsError(this.errorMessage, this.id, {this.read = false});

  final String errorMessage;
  final String id;
  final bool read;

  DevToolsError asRead() => DevToolsError(errorMessage, id, read: true);
}
