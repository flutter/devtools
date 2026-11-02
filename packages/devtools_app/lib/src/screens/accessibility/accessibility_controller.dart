// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ScrollController;
import 'package:logging/logging.dart';

import '../../service/service_extensions.dart' as extensions;
import '../../service/service_registrations.dart' as registrations;
import '../../service/view_metrics_override_client.dart';
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import 'semantics_node_model.dart';

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
    _initViewMetricsOverrides();
    _initSemanticsTree();
  }

  void _initListeners() {
    addAutoDisposeListener(brightness, _onBrightnessChanged);
    addAutoDisposeListener(semanticsRoots, _onSemanticsRootsChanged);
  }

  void _onSemanticsRootsChanged() {
    selectSemanticsNode(semanticsRoots.value.firstOrNull);
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

  // The metrics of `ext.flutter.viewMetricsOverride` that the overrides pane
  // controls. Brightness stays on `ext.flutter.brightnessOverride`.
  static const _textScalingMetric = 'textScaling';
  static const _boldTextMetric = 'boldText';
  static const _accessibleNavigationMetric = 'accessibleNavigation';
  static const _highContrastMetric = 'highContrast';

  /// The client that overrides the text scale, bold text, screen reader and
  /// high contrast settings of the app, or null before [init].
  ViewMetricsOverrideClient? _viewMetricsOverrideClient;

  void _initViewMetricsOverrides() {
    final client = _viewMetricsOverrideClient = ViewMetricsOverrideClient();
    void updateFromApp() {
      final overrides = client.overrides.value;
      _overridesAvailable.value = client.available.value;
      _textScale.value = _textScaleFactor(overrides[_textScalingMetric]);
      _boldText.value = overrides[_boldTextMetric] == true;
      _screenReader.value = overrides[_accessibleNavigationMetric] == true;
      _highContrast.value = overrides[_highContrastMetric] == true;
    }

    updateFromApp();
    addAutoDisposeListener(client.available, updateFromApp);
    addAutoDisposeListener(client.overrides, updateFromApp);
  }

  /// Overrides the text scale factor of the app with [factor], or stops
  /// overriding it if [factor] is null.
  ///
  /// The override scales every font size linearly by [factor].
  Future<void> setTextScale(double? factor) => _setOverride(
    _textScalingMetric,
    factor == null
        ? null
        : [
            [1, factor],
          ],
  );

  /// Makes the app use bold text, or the bold text setting of the platform
  /// again if [enabled] is false.
  Future<void> setBoldText(bool enabled) =>
      _setFlagOverride(_boldTextMetric, enabled);

  /// Makes the app behave as though a screen reader is on, or follow the
  /// platform again if [enabled] is false.
  Future<void> setScreenReader(bool enabled) =>
      _setFlagOverride(_accessibleNavigationMetric, enabled);

  /// Makes the app use high contrast, or the high contrast setting of the
  /// platform again if [enabled] is false.
  Future<void> setHighContrast(bool enabled) =>
      _setFlagOverride(_highContrastMetric, enabled);

  // Turning an override off stops overriding the flag rather than overriding
  // it to false, so that the app goes back to the setting of the platform.
  Future<void> _setFlagOverride(String metric, bool enabled) =>
      _setOverride(metric, enabled ? true : null);

  Future<void> _setOverride(String metric, Object? value) async {
    await _viewMetricsOverrideClient?.updateOverrides({metric: value});
  }

  /// Returns the ratio of the first point of [textScaling], which is the text
  /// scale factor that the app reports, or null if text scale is not
  /// overridden.
  static double? _textScaleFactor(Object? textScaling) {
    if (textScaling case [[final num unscaled, final num scaled], ...]) {
      return scaled / unscaled;
    }
    return null;
  }

  @override
  final screenId = ScreenMetaData.accessibility.id;

  // --- Accessibility Overrides State ---
  final brightness = ValueNotifier<BrightnessOverride>(
    BrightnessOverride.system,
  );

  /// Whether the connected app supports the text scale, bold text, screen
  /// reader and high contrast overrides.
  ///
  /// See [ViewMetricsOverrideClient.available] for the apps that do.
  ValueListenable<bool> get overridesAvailable => _overridesAvailable;
  final _overridesAvailable = ValueNotifier<bool>(false);

  /// The text scale factor that the app is overridden to, or null if the app
  /// uses the text scale that the platform reports.
  ValueListenable<double?> get textScale => _textScale;
  final _textScale = ValueNotifier<double?>(null);

  /// Whether the app is overridden to use bold text.
  ValueListenable<bool> get boldText => _boldText;
  final _boldText = ValueNotifier<bool>(false);

  /// Whether the app is overridden to behave as though a screen reader is on.
  ///
  /// This overrides `AccessibilityFeatures.accessibleNavigation`, which
  /// changes how widgets behave. It does not start a screen reader.
  ValueListenable<bool> get screenReader => _screenReader;
  final _screenReader = ValueNotifier<bool>(false);

  /// Whether the app is overridden to use high contrast.
  ValueListenable<bool> get highContrast => _highContrast;
  final _highContrast = ValueNotifier<bool>(false);

  final semanticsRoots = ValueNotifier<List<SemanticsNodeModel>>([]);
  final selectedSemanticsNode = ValueNotifier<SemanticsNodeModel?>(null);
  final semanticsTreeLoading = ValueNotifier<bool>(false);
  final semanticsTreeError = ValueNotifier<String?>(null);
  final treeScrollController = ScrollController();

  /// Selects [node] in the semantics tree and unselects any previously selected node.
  void selectSemanticsNode(SemanticsNodeModel? node) {
    if (selectedSemanticsNode.value == node) return;
    selectedSemanticsNode.value?.unselect();
    node?.select();
    selectedSemanticsNode.value = node;
  }

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
          .callServiceExtensionOnMainIsolate(
            registrations.getIssuesAndSemanticsTree,
          );

      if (disposed) return;

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

      final issuesMap = <String, List<AccessibilityIssue>>{};
      final rawIssues = json?['issues'];
      if (rawIssues is List<Object?>) {
        for (final rawIssue in rawIssues) {
          if (rawIssue is! Map) continue;
          final nodeId = rawIssue['nodeId']?.toString();
          if (nodeId != null) {
            issuesMap
                .putIfAbsent(nodeId, () => [])
                .add(
                  AccessibilityIssue(
                    rule: rawIssue['rule']?.toString() ?? '',
                    description: rawIssue['description']?.toString() ?? '',
                  ),
                );
          }
        }
      }

      final roots = <SemanticsNodeModel>[];
      if (rawData is Map<String, dynamic>) {
        if (rawData.isNotEmpty) {
          final rootId = rawData.containsKey('0')
              ? '0'
              : rawData.keys.first.toString();
          roots.add(
            _buildTreeFromNodesMap(rootId, rawData, <String>{}, issuesMap),
          );
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
      if (!disposed) {
        semanticsRoots.value = [];
        semanticsTreeError.value = 'Failed to load semantics tree: $e';
      }
    } finally {
      if (!disposed) {
        semanticsTreeLoading.value = false;
      }
    }
  }

  SemanticsNodeModel _buildTreeFromNodesMap(
    String nodeId,
    Map<String, dynamic> nodesMap,
    Set<String> visited,
    Map<String, List<AccessibilityIssue>> issuesMap,
  ) {
    if (!visited.add(nodeId)) {
      return SemanticsNodeModel(id: nodeId);
    }

    final json =
        (nodesMap[nodeId] as Map<String, dynamic>?) ??
        <String, dynamic>{'id': nodeId};
    final nodeIssues = issuesMap[nodeId] ?? const [];
    final node = _parseSemanticsNode(json, nodeIssues);

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
        final childNode = _buildTreeFromNodesMap(
          childId,
          nodesMap,
          visited,
          issuesMap,
        );
        node.addChild(childNode);
      }
    }

    return node;
  }

  SemanticsNodeModel _parseSemanticsNode(
    Map<String, dynamic> json, [
    List<AccessibilityIssue> issues = const [],
  ]) {
    final rawFlags = json['flags'] as List<Object?>?;
    final flags = SemanticsNodeModel.parseFlags(rawFlags);
    final rect = SemanticsNodeModel.parseRect(json['rect']);

    return SemanticsNodeModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
      rect: rect,
      flags: flags,
      issues: issues,
      widgetName: json['widgetName']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    unawaited(_disposeSemanticsOnApp());
    _viewMetricsOverrideClient?.dispose();
    brightness.dispose();
    _overridesAvailable.dispose();
    _textScale.dispose();
    _boldText.dispose();
    _screenReader.dispose();
    _highContrast.dispose();
    semanticsRoots.dispose();
    selectedSemanticsNode.dispose();
    semanticsTreeLoading.dispose();
    semanticsTreeError.dispose();
    treeScrollController.dispose();
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
