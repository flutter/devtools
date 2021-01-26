// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'auto_dispose.dart';
import 'globals.dart';
import 'inspector/inspector_screen.dart';
import 'listenable.dart';
import 'logging/logging_screen.dart';
import 'network/network_screen.dart';
import 'performance/performance_screen.dart';
import 'service_extensions.dart' as extensions;
import 'vm_service_wrapper.dart';

class ErrorBadgeManager extends DisposableController
    with AutoDisposeControllerMixin {
  final _activeErrorCounts = <String, ValueNotifier<int>>{
    InspectorScreen.id: ValueNotifier<int>(0),
    PerformanceScreen.id: ValueNotifier<int>(0),
    NetworkScreen.id: ValueNotifier<int>(0),
    LoggingScreen.id: ValueNotifier<int>(0),
  };
  final _activeErroredWidgets = ValueNotifier<List<InspectableWidgetError>>([]);

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
        appendInspectorErroredWidget(inspectableError);
      }
    }
  }

  InspectableWidgetError _extractInspectableError(Event error) {
    final json = error.extensionData.data;

    // TODO(dantup): Is there a better way to get the inspectorRef we need?
    final properties = json['properties'] as List<dynamic>;

    final errorSummaryNode = properties
        ?.firstWhere((p) => p['type'] == 'ErrorSummary', orElse: () => null);
    final errorMessage = errorSummaryNode != null
        ? errorSummaryNode['description'] as String
        : null;
    if (errorMessage == null) {
      return null;
    }

    final devToolsUrlNode = properties?.firstWhere(
        (p) => p['type'] == 'DevToolsDeepLinkProperty' && p['value'] != null,
        orElse: () => null);
    if (devToolsUrlNode == null) {
      return null;
    }

    var inspectWidgetUrl = Uri.tryParse(devToolsUrlNode['value'] as String);
    if (inspectWidgetUrl == null) {
      return null;
    }

    // Handle when querystring is in the fragement.
    if (inspectWidgetUrl.queryParameters.isEmpty &&
        inspectWidgetUrl.fragment.isNotEmpty) {
      inspectWidgetUrl = Uri.tryParse(inspectWidgetUrl.fragment);
    }
    final inspectorRef = inspectWidgetUrl != null
        ? inspectWidgetUrl.queryParameters['inspectorRef']
        : null;

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

  void appendInspectorErroredWidget(InspectableWidgetError error) {
    var currentErrors = _activeErroredWidgets.value;
    if (!currentErrors.any((e) => e.inspectorRef == error.inspectorRef)) {
      currentErrors = [...currentErrors, error];
      _activeErroredWidgets.value = currentErrors;
      _errorCountNotifier(InspectorScreen.id).value = currentErrors.length;
    }
  }

  ValueListenable<int> errorCountNotifier(String screenId) {
    return _errorCountNotifier(screenId) ?? const FixedValueListenable<int>(0);
  }

  ValueListenable<List<InspectableWidgetError>> erroredWidgetNotifier() {
    return _activeErroredWidgets;
  }

  ValueNotifier<int> _errorCountNotifier(String screenId) {
    return _activeErrorCounts[screenId];
  }

  void clearErrors(String screenId) {
    _activeErrorCounts[screenId]?.value = 0;
  }

  void filterInspectorErrors(bool Function(String value) isValid) {
    _activeErroredWidgets.value = _activeErroredWidgets.value
        .where((e) => isValid(e.inspectorRef))
        .toList();
    _errorCountNotifier(InspectorScreen.id).value =
        _activeErroredWidgets.value.length;
  }
}

class InspectableWidgetError {
  InspectableWidgetError(this.errorMessage, this.inspectorRef);

  final String errorMessage;
  final String inspectorRef;
}
