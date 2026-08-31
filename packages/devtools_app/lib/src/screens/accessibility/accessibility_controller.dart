// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../service/service_extensions.dart' as extensions;
import '../../service/service_registrations.dart' as registrations;
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import 'semantics_node_model.dart';

export 'semantics_node_model.dart';

final _log = Logger('accessibility_controller');

/// Modes for brightness override in the accessibility controls.
enum BrightnessOverride {
  system('System Default', 'system'),
  light('Light Mode', 'Brightness.light'),
  dark('Dark Mode', 'Brightness.dark');

  const BrightnessOverride(this.display, this.value);

  /// The user-facing display label for this override option.
  final String display;

  /// The raw value associated with this override option sent to or received
  /// from the VM service extension.
  final String value;
}

/// Controller for the Accessibility screen.
class AccessibilityController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  AccessibilityController() {
    _initListeners();
  }

  @override
  void init() {
    super.init();
    _initServiceExtensionStates();
    _initSemanticsTree();
  }

  void _initListeners() {
    addAutoDisposeListener(brightness, _onBrightnessChanged);
    addAutoDisposeListener(textScale, _onTextScaleChanged);
    addAutoDisposeListener(boldText, _onBoldTextChanged);
    addAutoDisposeListener(screenReader, _onScreenReaderChanged);
    addAutoDisposeListener(highContrast, _onHighContrastChanged);
  }

  void _initSemanticsTree() {
    if (serviceConnection.serviceManager.isolateManager.mainIsolate.value !=
        null) {
      unawaited(_autoLoadSemanticsTreeIfNeeded());
    }
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        if (serviceConnection.serviceManager.isolateManager.mainIsolate.value !=
            null) {
          // Clear stale data from a previous isolate so the guard in
          // _autoLoadSemanticsTreeIfNeeded doesn't skip the new load.
          semanticsRoots.value = [];
          semanticsTreeError.value = null;
          unawaited(_autoLoadSemanticsTreeIfNeeded());
        } else {
          semanticsRoots.value = [];
          semanticsTreeError.value = null;
        }
      },
    );
  }

  Future<void> _autoLoadSemanticsTreeIfNeeded() async {
    if (semanticsRoots.value.isEmpty &&
        semanticsTreeError.value == null &&
        !semanticsTreeLoading.value) {
      await loadSemanticsTree();
    }
  }

  void _initServiceExtensionStates() {
    final state = serviceConnection.serviceManager.serviceExtensionManager
        .getServiceExtensionState(extensions.brightnessMode.extension);

    void updateFromDeviceState(ServiceExtensionState state) {
      final newBrightness = !state.enabled || state.value == null
          ? BrightnessOverride.system
          : BrightnessOverride.values.firstWhere(
              (b) => b.value == state.value,
              orElse: () => BrightnessOverride.system,
            );
      brightness.value = newBrightness;
    }

    updateFromDeviceState(state.value);
    addAutoDisposeListener(state, () => updateFromDeviceState(state.value));
  }

  void _onBrightnessChanged() {
    final value = brightness.value;
    unawaited(
      serviceConnection.serviceManager.serviceExtensionManager
          .setServiceExtensionState(
            extensions.brightnessMode.extension,
            enabled: value != BrightnessOverride.system,
            value: value.value,
          ),
    );
  }

  void _onTextScaleChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for text scale override.
  }

  void _onBoldTextChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for bold text override.
  }

  void _onScreenReaderChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for screen reader / semantics debugger.
    // e.g. using 'ext.flutter.showSemanticsDebugger'.
  }

  void _onHighContrastChanged() {
    // TODO(hannah-hyj): Implement VM service extension call for high contrast override.
  }

  @override
  final screenId = ScreenMetaData.accessibility.id;

  // --- Accessibility Overrides State ---
  final brightness = ValueNotifier<BrightnessOverride>(
    BrightnessOverride.system,
  );
  final textScale = ValueNotifier<double>(1.0);
  final boldText = ValueNotifier<bool>(false);
  final screenReader = ValueNotifier<bool>(false);
  final highContrast = ValueNotifier<bool>(false);

  final semanticsRoots = ValueNotifier<List<SemanticsNodeModel>>([]);
  final semanticsTreeLoading = ValueNotifier<bool>(false);
  final semanticsTreeError = ValueNotifier<String?>(null);

  Future<void> loadSemanticsTree() async {
    if (semanticsTreeLoading.value) return;

    final mainIsolate =
        serviceConnection.serviceManager.isolateManager.mainIsolate.value;
    if (mainIsolate == null) {
      semanticsTreeError.value =
          'Failed to load semantics tree: no connected application.';
      return;
    }

    semanticsTreeLoading.value = true;
    semanticsTreeError.value = null;

    try {
      await serviceConnection.serviceManager.callServiceExtensionOnMainIsolate(
        registrations.enableSemantics,
        args: {'enabled': 'true'},
      );

      final response = await serviceConnection.serviceManager
          .callServiceExtensionOnMainIsolate(registrations.getSemanticsTree);

      final json = response.json;
      if (json != null && json.containsKey('error')) {
        throw Exception(json['error']);
      }

      final rawData = json?['data'];
      if (rawData == null) {
        throw Exception(
          'Empty semantics tree returned from service extension.',
        );
      }

      final roots = <SemanticsNodeModel>[];
      if (rawData is Map<String, dynamic>) {
        if (rawData.isNotEmpty) {
          final rootId = rawData.containsKey('0')
              ? '0'
              : rawData.keys.first.toString();
          roots.add(_buildTreeFromNodesMap(rootId, rawData, <String>{}));
        }
      }

      if (roots.isEmpty) {
        throw Exception('No semantics nodes found in response.');
      }

      for (final root in roots) {
        root.expandCascading();
      }
      semanticsRoots.value = roots;
      semanticsTreeError.value = null;
    } catch (e, st) {
      _log.warning('Error loading semantics tree: $e', e, st);
      semanticsRoots.value = [];
      semanticsTreeError.value = 'Failed to load semantics tree: $e';
    } finally {
      semanticsTreeLoading.value = false;
    }
  }

  SemanticsNodeModel _buildTreeFromNodesMap(
    String nodeId,
    Map<String, dynamic> nodesMap,
    Set<String> visited,
  ) {
    if (!visited.add(nodeId)) {
      return SemanticsNodeModel(id: nodeId);
    }

    final json =
        (nodesMap[nodeId] as Map<String, dynamic>?) ??
        <String, dynamic>{'id': nodeId};
    final node = _parseSemanticsNode(json);

    final childIds =
        (json['childrenInTraversalOrder'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        (json['childrenInHitTestOrder'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    for (final childId in childIds) {
      if (nodesMap.containsKey(childId)) {
        final childNode = _buildTreeFromNodesMap(childId, nodesMap, visited);
        node.addChild(childNode);
      }
    }

    return node;
  }

  SemanticsNodeModel _parseSemanticsNode(Map<String, dynamic> json) {
    final rawFlags = json['flags'] as List?;
    final flags = SemanticsNodeModel.parseFlags(rawFlags);

    return SemanticsNodeModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      flags: flags,
      widgetName: json['widgetName']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    unawaited(_disposeSemanticsOnApp());
    brightness.dispose();
    textScale.dispose();
    boldText.dispose();
    screenReader.dispose();
    highContrast.dispose();
    semanticsRoots.dispose();
    semanticsTreeLoading.dispose();
    semanticsTreeError.dispose();
    super.dispose();
  }

  Future<void> _disposeSemanticsOnApp() async {
    try {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        await serviceConnection.serviceManager
            .callServiceExtensionOnMainIsolate(registrations.disposeSemantics);
      }
    } catch (_) {
      // Ignore errors if the app or isolate connection is already closed.
    }
  }
}
