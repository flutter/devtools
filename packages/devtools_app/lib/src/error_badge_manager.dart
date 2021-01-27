// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'auto_dispose.dart';
import 'globals.dart';
import 'inspector/diagnostics_node.dart';
import 'inspector/inspector_screen.dart';
import 'listenable.dart';
import 'logging/logging_screen.dart';
import 'network/network_screen.dart';
import 'performance/performance_screen.dart';
import 'service_extensions.dart' as extensions;
import 'utils.dart';
import 'vm_service_wrapper.dart';

class ErrorBadgeManager extends DisposableController
    with AutoDisposeControllerMixin {
  final _activeErrorCounts = <String, ValueNotifier<int>>{
    InspectorScreen.id: ValueNotifier<int>(0),
    PerformanceScreen.id: ValueNotifier<int>(0),
    NetworkScreen.id: ValueNotifier<int>(0),
    LoggingScreen.id: ValueNotifier<int>(0),
  };
  final _activeErrors = <String, ValueNotifier<Map<String, DevToolsError>>>{
    InspectorScreen.id: ValueNotifier<Map<String, DevToolsError>>({}),
  };

  void vmServiceOpened(VmServiceWrapper service) {
    // Ensure structured errors are enabled.
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensions.structuredErrors.extension,
      true,
      true,
    );

    // Log Flutter extension events.
    autoDispose(
        service.onExtensionEventWithHistory.listen(_handleExtensionEvent));

    // Log stderr events.
    autoDispose(service.onStderrEventWithHistory.listen(_handleStdErr));
  }

  void _handleExtensionEvent(Event e) async {
    if (e.extensionKind == 'Flutter.Error') {
      incrementBadgeCount(LoggingScreen.id);

      final inspectableError = _extractInspectableError(e);
      if (inspectableError != null) {
        appendError(InspectorScreen.id, inspectableError);
      }
    }
  }

  InspectableWidgetError _extractInspectableError(Event error) {
    final node =
        RemoteDiagnosticsNode(error.extensionData.data, null, false, null);

    final errorSummaryNode = node.inlineProperties
        ?.firstWhere((p) => p.type == 'ErrorSummary', orElse: () => null);
    final errorMessage = errorSummaryNode?.description;
    if (errorMessage == null) {
      return null;
    }

    final devToolsUrlNode = node.inlineProperties?.firstWhere(
      (p) =>
          p.type == 'DevToolsDeepLinkProperty' &&
          p.getStringMember('value') != null,
      orElse: () => null,
    );
    if (devToolsUrlNode == null) {
      return null;
    }

    final queryParams =
        devToolsQueryParams(devToolsUrlNode.getStringMember('value'));
    final inspectorRef =
        queryParams != null ? queryParams['inspectorRef'] : null;

    return InspectableWidgetError(errorMessage, inspectorRef);
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

  void appendError(String screenId, DevToolsError error) {
    final currentErrors = _activeErrors[screenId];
    if (currentErrors == null) return;

    if (!currentErrors.value.containsKey(error.id)) {
      // Build a new map with the new error. Adding to the existing map
      // won't cause the ValueNotifier to fire (and it's not permitted to call
      // notifyListeners() directly).
      currentErrors.value = {
        ...currentErrors.value,
        error.id: error,
      };
      _errorCountNotifier(screenId).value = currentErrors.value.length;
    }
  }

  ValueListenable<int> errorCountNotifier(String screenId) {
    return _errorCountNotifier(screenId) ?? const FixedValueListenable<int>(0);
  }

  ValueListenable<Map<String, DevToolsError>> erroredWidgetNotifier(
      String screenId) {
    return _activeErrors[screenId] ??
        const FixedValueListenable<List<DevToolsError>>([]);
  }

  ValueNotifier<int> _errorCountNotifier(String screenId) {
    return _activeErrorCounts[screenId];
  }

  void clearErrors(String screenId) {
    _activeErrorCounts[screenId]?.value = 0;
  }

  void filterErrors(String screenId, bool Function(String value) isValid) {
    final activeErrors = _activeErrors[screenId];
    activeErrors.value = Map.fromEntries(
        activeErrors.value.entries.where((e) => isValid(e.key)));
    _errorCountNotifier(screenId).value = activeErrors.value.length;
  }
}

class DevToolsError {
  DevToolsError(this.errorMessage, this.id);

  final String errorMessage;
  final String id;
}

class InspectableWidgetError extends DevToolsError {
  InspectableWidgetError(String errorMessage, String id)
      : super(errorMessage, id);

  String get inspectorRef => id;
}
