// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:collection';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../../shared/analytics/metrics.dart';
import '../../shared/console/primitives/simple_items.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import '../../shared/managers/error_badge_manager.dart';
import '../../shared/primitives/query_parameters.dart';
import 'inspector_controller.dart';
import 'inspector_errors.dart';
import 'inspector_screen.dart';
import 'inspector_tree_controller.dart';

/// Screen controller for the Inspector screen.
///
/// This controller can be accessed from anywhere in DevTools, as long as it was
/// first registered, by
/// calling `screenControllers.lookup<InspectorScreenController>()`.
///
/// The controller lifecycle is managed by the [ScreenControllers] class. The
/// `init` method is called lazily upon the first controller access from
/// `screenControllers`. The `dispose` method is called by `screenControllers`
/// when DevTools is destroying a set of DevTools screen controllers.
class InspectorScreenController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  @override
  final screenId = ScreenMetaData.inspector.id;

  late InspectorController inspectorController;
  late InspectorTreeController inspectorTreeController;

  /// Stores the inspector-specific errors keyed by inspector reference ID.
  final _activeInspectorErrors =
      ValueNotifier<LinkedHashMap<String, DevToolsError>>(
        LinkedHashMap<String, DevToolsError>(),
      );

  /// The errors currently tracked for the inspector screen.
  ValueListenable<LinkedHashMap<String, DevToolsError>> get inspectorErrors =>
      _activeInspectorErrors;

  /// The count of unread inspector errors (used for the badge).
  ValueListenable<int> get inspectorErrorCount => serviceConnection
      .errorBadgeManager
      .errorCountNotifier(InspectorScreen.id);

  @override
  void init() {
    super.init();
    // Inspector owns unread state for its badge; scaffold tab switches must not
    // clear it. See https://github.com/flutter/devtools/pull/9805.
    serviceConnection.errorBadgeManager.manageErrorCount(InspectorScreen.id);

    inspectorTreeController = InspectorTreeController(
      gaId: InspectorScreenMetrics.summaryTreeGaId,
    );
    inspectorController = InspectorController(
      inspectorTree: inspectorTreeController,
      treeType: FlutterTreeType.widget,
    );

    // Listen for Flutter extension events to extract inspector-specific errors.
    // Match other screen controllers: attach now if connected, and on connect.
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _handleConnectionStart(serviceConnection.serviceManager.service!);
      }
    });
    if (serviceConnection.serviceManager.connectedAppInitialized) {
      _handleConnectionStart(serviceConnection.serviceManager.service!);
    }
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    autoDisposeStreamSubscription(
      service.onExtensionEventWithHistorySafe.listen(_handleExtensionEvent),
    );
  }

  void _handleExtensionEvent(Event e) {
    if (e.extensionKind == FlutterEvent.error) {
      final inspectableError = _extractInspectableError(e);
      if (inspectableError != null) {
        appendError(inspectableError);
      }
    }
  }

  InspectableWidgetError? _extractInspectableError(Event error) {
    final extensionData = error.extensionData;
    if (extensionData == null) return null;

    final node = RemoteDiagnosticsNode(extensionData.data, null, false, null);

    final errorSummaryNode = node.inlineProperties.firstWhereOrNull(
      (p) => p.type == 'ErrorSummary',
    );
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

    final queryParams = DevToolsQueryParams.fromUrl(
      devToolsUrlNode.getStringMember('value')!,
    );
    final inspectorRef = queryParams.inspectorRef ?? '';

    return InspectableWidgetError(errorMessage, inspectorRef);
  }

  /// Appends an error to the inspector's active errors and updates the badge
  /// count.
  void appendError(DevToolsError error) {
    final errors = _activeInspectorErrors;
    final previousError = errors.value[error.id];

    // Build a new map with the new error. Adding to the existing map
    // won't cause the ValueNotifier to fire (and it's not permitted to call
    // notifyListeners() directly).
    final newValue = LinkedHashMap<String, DevToolsError>.of(errors.value);
    newValue[error.id] = error;
    errors.value = newValue;

    if (previousError == null) {
      if (!error.read) {
        _incrementUnreadCount();
      }
      return;
    }

    if (previousError.read && !error.read) {
      _incrementUnreadCount();
    } else if (!previousError.read && error.read) {
      _decrementUnreadCount();
    }
  }

  /// Clears all inspector errors and resets the badge count.
  void clearErrors() {
    _activeInspectorErrors.value = LinkedHashMap<String, DevToolsError>();
    serviceConnection.errorBadgeManager.resetErrorCount(InspectorScreen.id);
  }

  /// Marks an error as read and decrements the unread count.
  void markErrorAsRead(DevToolsError error) {
    final errors = _activeInspectorErrors;

    // If this error doesn't exist anymore or is already read, nothing to do.
    final currentError = errors.value[error.id];
    if (currentError == null || currentError.read) {
      return;
    }

    // Otherwise, replace the map with a new one that has the error marked
    // as read.
    final newValue = LinkedHashMap<String, DevToolsError>.of(errors.value);
    newValue[error.id] = currentError.asRead();
    errors.value = newValue;
    _decrementUnreadCount();
  }

  void _incrementUnreadCount() {
    serviceConnection.errorBadgeManager.incrementBadgeCount(InspectorScreen.id);
  }

  void _decrementUnreadCount() {
    serviceConnection.errorBadgeManager.decrementBadgeCount(InspectorScreen.id);
  }

  @override
  void dispose() {
    _activeInspectorErrors.dispose();
    inspectorTreeController.dispose();
    inspectorController.dispose();
    super.dispose();
  }
}
