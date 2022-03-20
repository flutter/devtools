// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:collection';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/auto_dispose.dart';
import '../primitives/listenable.dart';
import '../primitives/utils.dart';
import '../screens/inspector/diagnostics_node.dart';
import '../screens/inspector/inspector_screen.dart';
import '../screens/logging/logging_screen.dart';
import '../screens/network/network_screen.dart';
import '../screens/performance/performance_screen.dart';
import '../service/service_extensions.dart' as extensions;
import '../service/vm_service_wrapper.dart';
import 'globals.dart';

class ErrorBadgeManager extends DisposableController
    with AutoDisposeControllerMixin {
  final _activeErrorCounts = <String, ValueNotifier<int>>{
    InspectorScreen.id: ValueNotifier<int>(0),
    PerformanceScreen.id: ValueNotifier<int>(0),
    NetworkScreen.id: ValueNotifier<int>(0),
  };
  final _activeErrors =
      <String, ValueNotifier<LinkedHashMap<String, DevToolsError>>>{
    InspectorScreen.id: ValueNotifier<LinkedHashMap<String, DevToolsError>>(
        LinkedHashMap<String, DevToolsError>()),
  };

  void vmServiceOpened(VmServiceWrapper service) {
    // Ensure structured errors are enabled.
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensions.structuredErrors.extension,
      enabled: true,
      value: true,
    );

    // Log Flutter extension events.
    autoDisposeStreamSubscription(
        service.onExtensionEventWithHistory.listen(_handleExtensionEvent));

    // Log stderr events.
    autoDisposeStreamSubscription(
        service.onStderrEventWithHistory.listen(_handleStdErr));
  }

  void _handleExtensionEvent(Event e) async {
    if (e.extensionKind == 'Flutter.Error') {
      incrementBadgeCount(LoggingScreen.id);

      final inspectableError = _extractInspectableError(e);
      if (inspectableError != null) {
        incrementBadgeCount(InspectorScreen.id);
        appendError(InspectorScreen.id, inspectableError);
      }
    }
  }

  InspectableWidgetError? _extractInspectableError(Event error) {
    // TODO(dantup): Switch to using the inspectorService from the serviceManager
    //  once Jacob's change to add it lands.
    final node =
        RemoteDiagnosticsNode(error.extensionData!.data, null, false, null);

    final errorSummaryNode =
        node.inlineProperties.firstWhereOrNull((p) => p.type == 'ErrorSummary');
    final errorMessage = errorSummaryNode?.description;
    if (errorMessage == null) {
      return null;
    }

    final devToolsUrlNode = node.inlineProperties.firstWhereOrNull(
      (p) =>
          p.type == 'DevToolsDeepLinkProperty' &&
          p.getStringMember('value') != null,
    );
    if (devToolsUrlNode == null) {
      return null;
    }

    final queryParams =
        devToolsQueryParams(devToolsUrlNode.getStringMember('value')!);
    final inspectorRef = queryParams['inspectorRef'] ?? '';

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
    final ValueNotifier<LinkedHashMap<String?, DevToolsError>>? errors =
        _activeErrors[screenId];
    if (errors == null) return;

    // Build a new map with the new error. Adding to the existing map
    // won't cause the ValueNotifier to fire (and it's not permitted to call
    // notifyListeners() directly).
    final newValue = LinkedHashMap<String, DevToolsError>.from(errors.value);
    newValue[error.id] = error;
    errors.value = newValue;
  }

  ValueListenable<int> errorCountNotifier(String screenId) {
    return _errorCountNotifier(screenId) ?? const FixedValueListenable<int>(0);
  }

  ValueListenable<LinkedHashMap<String, DevToolsError>> erroredItemsForPage(
      String screenId) {
    return _activeErrors[screenId] ??
        FixedValueListenable<LinkedHashMap<String, DevToolsError>>(
            LinkedHashMap<String, DevToolsError>());
  }

  ValueNotifier<int>? _errorCountNotifier(String screenId) {
    return _activeErrorCounts[screenId];
  }

  void clearErrors(String screenId) {
    _activeErrorCounts[screenId]?.value = 0;
  }

  void filterErrors(String screenId, bool Function(String id) isValid) {
    final errors = _activeErrors[screenId];
    if (errors == null) return;

    final oldCount = errors.value.length;
    final newValue =
        Map.fromEntries(errors.value.entries.where((e) => isValid(e.key)));
    if (newValue.length != oldCount) {
      errors.value = newValue as LinkedHashMap<String, DevToolsError>;
    }
  }

  void markErrorAsRead(String screenId, DevToolsError error) {
    final errors = _activeErrors[screenId];
    if (errors == null) return;

    // If this error doesn't exist anymore or is already read, nothing to do.
    if (errors.value[error.id]?.read ?? true) {
      return;
    }

    // Otherwise, replace the map with a new one that has the error marked
    // as read.
    errors.value = LinkedHashMap<String, DevToolsError>.fromEntries(
      errors.value.entries.map((e) {
        if (e.value != error) return e;
        return MapEntry(e.key, e.value.asRead());
      }),
    );
  }
}

class DevToolsError {
  DevToolsError(this.errorMessage, this.id, {this.read = false});

  final String errorMessage;
  final String id;
  final bool read;

  DevToolsError asRead() => DevToolsError(errorMessage, id, read: true);
}

class InspectableWidgetError extends DevToolsError {
  InspectableWidgetError(String errorMessage, String id, {bool read = false})
      : super(errorMessage, id, read: read);

  String get inspectorRef => id;

  @override
  InspectableWidgetError asRead() =>
      InspectableWidgetError(errorMessage, id, read: true);
}
