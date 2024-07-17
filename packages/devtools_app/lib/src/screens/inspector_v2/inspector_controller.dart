// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library must not have direct dependencies on dart:html.
///
/// This allows tests of the complicated logic in this class to run on the VM
/// and will help simplify porting this code to work with Hummingbird.
///
/// This code is directly based on
/// src/io/flutter/view/InspectorPanel.java
/// with some refactors to make the code more of a controller than a combination
/// of view and controller. View specific portions of InspectorPanel.java have
/// been moved to inspector.dart.
library;

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/service_extensions.dart' as extensions;
import '../../shared/console/eval/inspector_tree_v2.dart';
import '../../shared/console/primitives/simple_items.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/diagnostics/inspector_service.dart';
import '../../shared/diagnostics/primitives/instance_ref.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import 'inspector_screen.dart';
import 'inspector_tree_controller.dart';

final _log = Logger('inspector_controller');

const inspectorRefQueryParam = 'inspectorRef';

/// This class is based on the InspectorPanel class from the Flutter IntelliJ
/// plugin with some refactors to make it more of a true controller than a view.
class InspectorController extends DisposableController
    with AutoDisposeControllerMixin
    implements InspectorServiceClient {
  InspectorController({
    required this.inspectorTree,
    required this.treeType,
  }) {
    unawaited(_init());
  }

  Future<void> _init() async {
    _refreshRateLimiter = RateLimiter(refreshFramesPerSecond, refresh);

    inspectorTree.config = InspectorTreeConfig(
      onNodeAdded: _onNodeAdded,
      onSelectionChange: selectionChanged,
      onExpand: _onExpand,
      onClientActiveChange: _onClientChange,
    );
    await serviceConnection.serviceManager.onServiceAvailable;

    if (inspectorService is InspectorService) {
      _treeGroups = InspectorObjectGroupManager(
        serviceConnection.inspectorService as InspectorService,
        'tree',
      );
      _selectionGroups = InspectorObjectGroupManager(
        serviceConnection.inspectorService as InspectorService,
        'selection',
      );
    }

    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        final isolate =
            serviceConnection.serviceManager.isolateManager.mainIsolate.value;
        if (isolate != _mainIsolate) {
          onIsolateStopped();
        }
        _mainIsolate = isolate;
      },
    );

    // If select mode is available, enable the on device inspector as it
    // won't interfere with users.
    addAutoDisposeListener(_supportsToggleSelectWidgetMode, () {
      if (_supportsToggleSelectWidgetMode.value) {
        serviceConnection.serviceManager.serviceExtensionManager
            .setServiceExtensionState(
          extensions.enableOnDeviceInspector.extension,
          enabled: true,
          value: true,
        );
      }
    });

    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _handleConnectionStart();
      } else {
        _handleConnectionStop();
      }
    });

    if (serviceConnection.serviceManager.connectedAppInitialized) {
      _handleConnectionStart();
    }

    serviceConnection.consoleService.ensureServiceInitialized();
  }

  void _handleConnectionStart() {
    // Clear any existing badge/errors for older errors that were collected.
    // Do this in a post frame callback so that we are not trying to clear the
    // error notifiers for this screen while the framework is already in the
    // process of building widgets.
    // TODO(kenz): When this method is called outside  createState(), this post
    // frame callback can be removed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      serviceConnection.errorBadgeManager.clearErrors(InspectorScreen.id);
    });
    filterErrors();
  }

  void _handleConnectionStop() {
    setActivate(false);
    dispose();
  }

  IsolateRef? _mainIsolate;

  ValueListenable<bool> get _supportsToggleSelectWidgetMode =>
      serviceConnection.serviceManager.serviceExtensionManager
          .hasServiceExtension(extensions.toggleSelectWidgetMode.extension);

  void _onClientChange(bool added) {
    if (!added && _clientCount == 0) {
      // Don't try to remove clients if there are none
      return;
    }

    _clientCount += added ? 1 : -1;
    assert(_clientCount >= 0);
    if (_clientCount == 1) {
      setVisibleToUser(true);
      setActivate(true);
    } else if (_clientCount == 0) {
      setVisibleToUser(false);
    }
  }

  int _clientCount = 0;

  /// Maximum frame rate to refresh the inspector at to avoid taxing the
  /// physical device with too many requests to recompute properties and trees.
  ///
  /// A value up to around 30 frames per second could be reasonable for
  /// debugging highly interactive cases particularly when the user is on a
  /// simulator or high powered native device. The frame rate is set low
  /// for now mainly to minimize risk.
  static const refreshFramesPerSecond = 5.0;

  InspectorTreeController inspectorTree;
  final FlutterTreeType treeType;

  bool _disposed = false;

  late RateLimiter _refreshRateLimiter;

  InspectorServiceBase get inspectorService =>
      serviceConnection.inspectorService as InspectorServiceBase;

  /// Groups used to manage and cancel requests to load data to display directly
  /// in the tree.
  InspectorObjectGroupManager? _treeGroups;

  /// Groups used to manage and cancel requests to determine what the current
  /// selection is.
  ///
  /// This group needs to be kept separate from treeGroups as the selection is
  /// shared with the widget details.
  /// TODO(jacobr): is there a way we can unify the selection and tree groups?
  InspectorObjectGroupManager? _selectionGroups;

  /// Node being highlighted due to the current hover.
  InspectorTreeNode? get currentShowNode => inspectorTree.hover;

  set currentShowNode(InspectorTreeNode? node) => inspectorTree.hover = node;

  bool flutterAppFrameReady = false;

  bool treeLoadStarted = false;

  RemoteDiagnosticsNode? subtreeRoot;

  bool programmaticSelectionChangeInProgress = false;

  ValueListenable<InspectorTreeNode?> get selectedNode => _selectedNode;
  final _selectedNode = ValueNotifier<InspectorTreeNode?>(null);

  InspectorTreeNode? lastExpanded;

  bool isActive = false;

  final valueToInspectorTreeNode = <InspectorInstanceRef, InspectorTreeNode>{};

  /// When visibleToUser is false we should dispose all allocated objects and
  /// not perform any actions.
  bool visibleToUser = false;

  bool highlightNodesShownInBothTrees = false;

  RemoteDiagnosticsNode? get selectedDiagnostic =>
      selectedNode.value?.diagnostic;

  final _selectedErrorIndex = ValueNotifier<int?>(null);

  ValueListenable<int?> get selectedErrorIndex => _selectedErrorIndex;

  /// Tracks whether the first load of the inspector tree has been completed.
  ///
  /// This field is used to prevent sending multiple analytics events for
  /// inspector tree load timing.
  bool firstInspectorTreeLoadCompleted = false;

  FlutterTreeType getTreeType() {
    return treeType;
  }

  void setVisibleToUser(bool visible) {
    if (visibleToUser == visible) {
      return;
    }
    visibleToUser = visible;

    if (visibleToUser) {
    } else {
      shutdownTree(false);
    }
  }

  bool hasDiagnosticsValue(InspectorInstanceRef ref) {
    return valueToInspectorTreeNode.containsKey(ref);
  }

  RemoteDiagnosticsNode? findDiagnosticsValue(InspectorInstanceRef ref) {
    return valueToInspectorTreeNode[ref]?.diagnostic;
  }

  void endShowNode() {
    highlightShowNode(null);
  }

  bool highlightShowFromNodeInstanceRef(InspectorInstanceRef ref) {
    return highlightShowNode(valueToInspectorTreeNode[ref]);
  }

  bool highlightShowNode(InspectorTreeNode? node) {
    currentShowNode = node;
    return true;
  }

  InspectorTreeNode? findMatchingInspectorTreeNode(
    RemoteDiagnosticsNode? node,
  ) {
    final valueRef = node?.valueRef;
    if (valueRef == null) {
      return null;
    }
    return valueToInspectorTreeNode[valueRef];
  }

  Future<void> _waitForPendingUpdateDone() async {
    // Wait for the selection to be resolved followed by waiting for the tree to be computed.
    await _selectionGroups?.pendingUpdateDone;
    await _treeGroups?.pendingUpdateDone;
    // TODO(jacobr): are there race conditions we need to think more carefully about here?
  }

  Future<void> refresh() {
    if (!visibleToUser) {
      // We will refresh again once we are visible.
      // There is a risk a refresh got triggered before the view was visble.
      return Future.value();
    }

    return _waitForPendingUpdateDone();
  }

  // Note that this may be called after the controller is disposed.  We need to handle nulls in the fields.
  void shutdownTree(bool isolateStopped) {
    // It is critical we clear all data that is kept alive by inspector object
    // references in this method as that stale data will trigger inspector
    // exceptions.
    programmaticSelectionChangeInProgress = true;
    _treeGroups?.clear(isolateStopped);
    _selectionGroups?.clear(isolateStopped);

    currentShowNode = null;
    _selectedNode.value = null;
    lastExpanded = null;

    subtreeRoot = null;

    inspectorTree.root = inspectorTree.createNode();
    programmaticSelectionChangeInProgress = false;
    valueToInspectorTreeNode.clear();
  }

  void onIsolateStopped() {
    flutterAppFrameReady = false;
    treeLoadStarted = false;
    shutdownTree(true);
  }

  @override
  Future<void> onForceRefresh() async {
    assert(!_disposed);
    if (!visibleToUser || _disposed) {
      return;
    }
    await _recomputeTreeRoot(null);
    if (_disposed) {
      return;
    }

    filterErrors();

    return _waitForPendingUpdateDone();
  }

  void filterErrors() {
    serviceConnection.errorBadgeManager.filterErrors(
      InspectorScreen.id,
      (id) => hasDiagnosticsValue(InspectorInstanceRef(id)),
    );
  }

  void setActivate(bool enabled) {
    if (!enabled) {
      onIsolateStopped();
      isActive = false;
      return;
    }
    if (isActive) {
      // Already activated.
      return;
    }

    isActive = true;
    inspectorService.addClient(this);
    unawaited(maybeLoadUI());
  }

  Future<void> maybeLoadUI() async {
    if (!visibleToUser || !isActive) {
      return;
    }

    if (flutterAppFrameReady) {
      if (_disposed) return;
      // We need to start by querying the inspector service to find out the
      // current state of the UI.

      final queryParams = loadQueryParams();
      final inspectorRef = queryParams.containsKey(inspectorRefQueryParam)
          ? queryParams[inspectorRefQueryParam]
          : null;
      await updateSelectionFromService(
        inspectorRef: inspectorRef,
      );
    } else {
      if (_disposed) return;
      if (inspectorService is InspectorService) {
        final widgetTreeReady =
            await (inspectorService as InspectorService).isWidgetTreeReady();
        flutterAppFrameReady = widgetTreeReady;
      }
      if (isActive && flutterAppFrameReady) {
        await maybeLoadUI();
      }
    }
  }

  Future<void> _recomputeTreeRoot(RemoteDiagnosticsNode? newSelection) async {
    assert(!_disposed);
    final treeGroups = _treeGroups;
    if (_disposed || treeGroups == null) {
      return;
    }

    treeGroups.cancelNext();
    try {
      final group = treeGroups.next;
      final node = await group.getRoot(treeType);
      if (node == null || group.disposed || _disposed) {
        return;
      }
      // TODO(jacobr): as a performance optimization we should check if the
      // new tree is identical to the existing tree in which case we should
      // dispose the new tree and keep the old tree.
      treeGroups.promoteNext();
      _clearValueToInspectorTreeNodeMapping();

      final rootNode = inspectorTree.setupInspectorTreeNode(
        inspectorTree.createNode(),
        node,
        expandChildren: true,
      );
      inspectorTree.root = rootNode;

      refreshSelection(newSelection);
    } catch (error, st) {
      _log.shout(error, error, st);
      treeGroups.cancelNext();
      return;
    }
  }

  void _clearValueToInspectorTreeNodeMapping() {
    valueToInspectorTreeNode.clear();
  }

  void setSubtreeRoot(
    RemoteDiagnosticsNode? node,
    RemoteDiagnosticsNode? selection,
  ) {
    selection ??= node;
    if (node != null && node == subtreeRoot) {
      //  Select the new node in the existing subtree.
      applyNewSelection(selection);
      return;
    }
    subtreeRoot = node;
    if (node == null) {
      // Passing in a null node indicates we should clear the subtree and free any memory allocated.
      shutdownTree(false);
      return;
    }

    // Clear now to eliminate frame of highlighted nodes flicker.
    _clearValueToInspectorTreeNodeMapping();
    unawaited(_recomputeTreeRoot(selection));
  }

  InspectorTreeNode? getSubtreeRootNode() {
    if (subtreeRoot == null) {
      return null;
    }
    return valueToInspectorTreeNode[subtreeRoot!.valueRef];
  }

  void refreshSelection(RemoteDiagnosticsNode? newSelection) {
    newSelection ??= selectedDiagnostic;
    setSelectedNode(findMatchingInspectorTreeNode(newSelection));
    syncSelectionHelper(selection: newSelection);

    syncTreeSelection();
  }

  void syncTreeSelection() {
    programmaticSelectionChangeInProgress = true;
    inspectorTree.selection = selectedNode.value;
    inspectorTree.expandPath(selectedNode.value);
    programmaticSelectionChangeInProgress = false;
    animateTo(selectedNode.value);
  }

  void selectAndShowNode(RemoteDiagnosticsNode? node) {
    if (node == null) {
      return;
    }
    selectAndShowInspectorInstanceRef(node.valueRef);
  }

  void selectAndShowInspectorInstanceRef(InspectorInstanceRef ref) {
    final node = valueToInspectorTreeNode[ref];
    if (node == null) {
      return;
    }
    setSelectedNode(node);
    syncTreeSelection();
  }

  InspectorTreeNode? getTreeNode(RemoteDiagnosticsNode node) {
    return valueToInspectorTreeNode[node.valueRef];
  }

  void maybeUpdateValueUI(InspectorInstanceRef valueRef) {
    final node = valueToInspectorTreeNode[valueRef];
    if (node == null) {
      return;
    }
    inspectorTree.nodeChanged(node);
  }

  @override
  void onFlutterFrame() {
    flutterAppFrameReady = true;
    if (!visibleToUser) {
      return;
    }

    if (!treeLoadStarted) {
      treeLoadStarted = true;
      // This was the first frame.
      unawaited(maybeLoadUI());
    }
    _refreshRateLimiter.scheduleRequest();
  }

  @override
  void onInspectorSelectionChanged() {
    if (!visibleToUser) {
      // Don't do anything. We will update the view once it is visible again.
      return;
    }
    unawaited(updateSelectionFromService());
  }

  Future<void> updateSelectionFromService({
    String? inspectorRef,
  }) async {
    final selectionGroups = _selectionGroups;
    if (selectionGroups == null) {
      // Already disposed. Ignore this requested to update selection.
      return;
    }
    treeLoadStarted = true;

    selectionGroups.cancelNext();

    final group = selectionGroups.next;

    if (inspectorRef != null) {
      await group.setSelectionInspector(
        InspectorInstanceRef(inspectorRef),
        false,
      );
      if (_disposed) return;
    }
    final pendingSelectionFuture = group.getSelection(
      selectedDiagnostic,
      treeType,
    );

    try {
      final newSelection = await pendingSelectionFuture;
      if (_disposed || group.disposed) return;

      selectionGroups.promoteNext();

      subtreeRoot = newSelection;

      applyNewSelection(newSelection);
    } catch (error, st) {
      if (selectionGroups.next == group) {
        _log.shout(error, error, st);
        selectionGroups.cancelNext();
      }
    }
  }

  void applyNewSelection(RemoteDiagnosticsNode? newSelection) {
    final nodeInTree = findMatchingInspectorTreeNode(newSelection);

    if (nodeInTree == null) {
      // The tree has probably changed since we last updated. Do a full refresh
      // so that the tree includes the new node we care about.
      unawaited(_recomputeTreeRoot(newSelection));
    }

    refreshSelection(newSelection);
  }

  void animateTo(InspectorTreeNode? node) {
    if (node == null) {
      return;
    }

    inspectorTree.animateToTargets([node]);
  }

  void setSelectedNode(InspectorTreeNode? newSelection) {
    if (newSelection == selectedNode.value) {
      return;
    }

    _selectedNode.value = newSelection;

    lastExpanded = null; // New selected node takes precedence.
    endShowNode();

    _updateSelectedErrorFromNode(_selectedNode.value);
    animateTo(selectedNode.value);
  }

  /// Update the index of the selected error based on a node that has been
  /// selected in the tree.
  void _updateSelectedErrorFromNode(InspectorTreeNode? node) {
    final inspectorRef = node?.diagnostic?.valueRef.id;

    final errors = serviceConnection.errorBadgeManager
        .erroredItemsForPage(InspectorScreen.id)
        .value;

    // Check whether the node that was just selected has any errors associated
    // with it.
    var errorIndex = inspectorRef != null
        ? errors.keys.toList().indexOf(inspectorRef)
        : null;
    if (errorIndex == -1) {
      errorIndex = null;
    }

    _selectedErrorIndex.value = errorIndex;

    if (errorIndex != null) {
      // Mark the error as "seen" as this will render slightly differently
      // so the user can track which errored nodes they've viewed.
      serviceConnection.errorBadgeManager
          .markErrorAsRead(InspectorScreen.id, errors[inspectorRef!]!);
      // Also clear the error badge since new errors may have arrived while
      // the inspector was visible (normally they're cleared when visiting
      // the screen) and visiting an errored node seems an appropriate
      // acknowledgement of the errors.
      serviceConnection.errorBadgeManager.clearErrors(InspectorScreen.id);
    }
  }

  /// Updates the index of the selected error and selects its node in the tree.
  void selectErrorByIndex(int index) {
    _selectedErrorIndex.value = index;

    final errors = serviceConnection.errorBadgeManager
        .erroredItemsForPage(InspectorScreen.id)
        .value;

    unawaited(
      updateSelectionFromService(
        inspectorRef: errors.keys.elementAt(index),
      ),
    );
  }

  void _onExpand(InspectorTreeNode node) {
    unawaited(inspectorTree.maybePopulateChildren(node));
  }

  Future<void> _addNodeToConsole(InspectorTreeNode node) async {
    final valueRef = node.diagnostic!.valueRef;
    final isolateRef = inspectorService.isolateRef;
    final instanceRef = await node.diagnostic!.objectGroupApi
        ?.toObservatoryInstanceRef(valueRef);
    if (_disposed) return;

    if (instanceRef != null) {
      await serviceConnection.consoleService.appendInstanceRef(
        value: instanceRef,
        diagnostic: node.diagnostic,
        isolateRef: isolateRef,
        forceScrollIntoView: true,
      );
    }
  }

  void selectionChanged() {
    if (!visibleToUser) {
      return;
    }

    final node = inspectorTree.selection;
    if (node != null) {
      unawaited(inspectorTree.maybePopulateChildren(node));
    }
    if (programmaticSelectionChangeInProgress) {
      return;
    }
    if (node != null) {
      setSelectedNode(node);
      unawaited(_addNodeToConsole(node));

      syncSelectionHelper(selection: selectedDiagnostic);
    }
  }

  void syncSelectionHelper({required RemoteDiagnosticsNode? selection}) {
    if (selection != null) {
      if (selection.isCreatedByLocalProject) {
        _navigateTo(selection);
      }
    }

    if (selection != null) {
      unawaited(selection.setSelectionInspector(true));
    }
  }

  // TODO(jacobr): implement this method and use the parameter.
  // ignore: avoid-unused-parameters
  void _navigateTo(RemoteDiagnosticsNode diagnostic) {
    // TODO(jacobr): dispatch an event over the inspectorService requesting a
    //  navigate operation.
  }

  @override
  void dispose() {
    assert(!_disposed);
    _disposed = true;
    if (serviceConnection.inspectorService != null) {
      shutdownTree(false);
    }
    _treeGroups?.clear(false);
    _treeGroups = null;
    _selectionGroups?.clear(false);
    _selectionGroups = null;
    super.dispose();
  }

  void _onNodeAdded(
    InspectorTreeNode node,
    RemoteDiagnosticsNode diagnosticsNode,
  ) {
    final valueRef = diagnosticsNode.valueRef;
    // Properties do not have unique values so should not go in the valueToInspectorTreeNode map.
    if (valueRef.id != null && !diagnosticsNode.isProperty) {
      valueToInspectorTreeNode[valueRef] = node;
    }
  }
}
