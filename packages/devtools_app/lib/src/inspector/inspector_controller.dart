// Copyright 2019 The Chromium Authors. All rights reserved.
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
library inspector_controller;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../config_specific/logger/logger.dart';
import '../config_specific/url/url.dart';
import '../globals.dart';
import '../service_extensions.dart' as extensions;
import '../service_registrations.dart' as registrations;
import '../utils.dart';
import '../version.dart';
import 'diagnostics_node.dart';
import 'inspector_screen.dart';
import 'inspector_service.dart';
import 'inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_tree.dart';

const inspectorRefQueryParam = 'inspectorRef';

TextStyle textStyleForLevel(DiagnosticLevel level, ColorScheme colorScheme) {
  switch (level) {
    case DiagnosticLevel.hidden:
      return inspector_text_styles.unimportant(colorScheme);
    case DiagnosticLevel.warning:
      return inspector_text_styles.warning(colorScheme);
    case DiagnosticLevel.error:
      return inspector_text_styles.error(colorScheme);
    case DiagnosticLevel.debug:
    case DiagnosticLevel.info:
    case DiagnosticLevel.fine:
    default:
      return inspector_text_styles.regular;
  }
}

class InspectorSettingsController {
  /// Whether to only show user defined widgets in the summary tree.
  final ValueNotifier<bool> showOnlyUserDefined = ValueNotifier(false);

  /// Whether to automatically show all widgets in the current build method even
  /// if they would otherwise be filtered.
  final ValueNotifier<bool> expandSelectedBuildMethod = ValueNotifier(true);
}

/// This class is based on the InspectorPanel class from the Flutter IntelliJ
/// plugin with some refactors to make it more of a true controller than a view.
class InspectorController extends DisposableController
    with AutoDisposeControllerMixin
    implements InspectorServiceClient {
  InspectorController({
    @required this.inspectorTree,
    InspectorTreeController detailsTree,
    @required this.treeType,
    this.parent,
    this.isSummaryTree = true,
    this.onExpandCollapseSupported,
    this.onLayoutExplorerSupported,
  })  : _treeGroups = InspectorObjectGroupManager(
          serviceManager.inspectorService,
          'tree',
        ),
        _selectionGroups = InspectorObjectGroupManager(
          serviceManager.inspectorService,
          'selection',
        ) {
    _refreshRateLimiter = RateLimiter(refreshFramesPerSecond, refresh);

    assert(inspectorTree != null);
    inspectorTree.config = InspectorTreeConfig(
      summaryTree: isSummaryTree,
      treeType: treeType,
      onNodeAdded: _onNodeAdded,
      onHover: highlightShowNode,
      onSelectionChange: selectionChanged,
      onExpand: _onExpand,
      onClientActiveChange: _onClientChange,
    );
    if (isSummaryTree) {
      details = InspectorController(
        inspectorTree: detailsTree,
        treeType: treeType,
        parent: this,
        isSummaryTree: false,
      );
    } else {
      details = null;
    }

    _checkForExpandCollapseSupport();
    _checkForLayoutExplorerSupport();

    addAutoDisposeListener(serviceManager.isolateManager.mainIsolate, () {
      final isolate = serviceManager.isolateManager.mainIsolate.value;
      if (isolate != _mainIsolate) {
        onIsolateStopped();
      }
      _mainIsolate = isolate;
    });

    // This logic only needs to be run once so run it in the outermost
    // controller.
    if (parent == null) {
      // If select mode is available, enable the on device inspector as it
      // won't interfere with users.
      addAutoDisposeListener(_supportsToggleSelectWidgetMode, () {
        if (_supportsToggleSelectWidgetMode.value) {
          serviceManager.serviceExtensionManager.setServiceExtensionState(
            extensions.enableOnDeviceInspector.extension,
            true,
            true,
          );
        }
      });
    }
  }

  IsolateRef _mainIsolate;

  ValueListenable<bool> get _supportsToggleSelectWidgetMode =>
      serviceManager.serviceExtensionManager
          .hasServiceExtension(extensions.toggleSelectWidgetMode.extension);

  void _onClientChange(bool added) {
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
  static const double refreshFramesPerSecond = 5.0;

  final bool isSummaryTree;

  final VoidCallback onExpandCollapseSupported;

  final VoidCallback onLayoutExplorerSupported;

  /// Parent InspectorController if this is a details subtree.
  InspectorController parent;

  InspectorController details;

  InspectorTreeController inspectorTree;
  final FlutterTreeType treeType;

  bool _disposed = false;

  RateLimiter _refreshRateLimiter;

  /// Groups used to manage and cancel requests to load data to display directly
  /// in the tree.
  InspectorObjectGroupManager _treeGroups;

  /// Groups used to manage and cancel requests to determine what the current
  /// selection is.
  ///
  /// This group needs to be kept separate from treeGroups as the selection is
  /// shared more with the details subtree.
  /// TODO(jacobr): is there a way we can unify the selection and tree groups?
  InspectorObjectGroupManager _selectionGroups;

  /// Node being highlighted due to the current hover.
  InspectorTreeNode get currentShowNode => inspectorTree.hover;

  set currentShowNode(InspectorTreeNode node) => inspectorTree.hover = node;

  bool flutterAppFrameReady = false;

  bool treeLoadStarted = false;

  RemoteDiagnosticsNode subtreeRoot;

  bool programaticSelectionChangeInProgress = false;

  ValueListenable<InspectorTreeNode> get selectedNode => _selectedNode;
  final ValueNotifier<InspectorTreeNode> _selectedNode = ValueNotifier(null);

  InspectorTreeNode lastExpanded;

  bool isActive = false;

  final Map<InspectorInstanceRef, InspectorTreeNode> valueToInspectorTreeNode =
      {};

  /// When visibleToUser is false we should dispose all allocated objects and
  /// not perform any actions.
  bool visibleToUser = false;

  bool highlightNodesShownInBothTrees = false;

  bool get detailsSubtree => parent != null;

  RemoteDiagnosticsNode get selectedDiagnostic =>
      selectedNode.value?.diagnostic;

  final ValueNotifier<int> _selectedErrorIndex = ValueNotifier<int>(null);

  ValueListenable<int> get selectedErrorIndex => _selectedErrorIndex;

  FlutterTreeType getTreeType() {
    return treeType;
  }

  void setVisibleToUser(bool visible) {
    if (visibleToUser == visible) {
      return;
    }
    visibleToUser = visible;

    if (visibleToUser) {
      if (parent == null) {
        maybeLoadUI();
      }
    } else {
      shutdownTree(false);
    }
  }

  bool hasDiagnosticsValue(InspectorInstanceRef ref) {
    return valueToInspectorTreeNode.containsKey(ref);
  }

  RemoteDiagnosticsNode findDiagnosticsValue(InspectorInstanceRef ref) {
    return valueToInspectorTreeNode[ref]?.diagnostic;
  }

  void endShowNode() {
    highlightShowNode(null);
  }

  bool highlightShowFromNodeInstanceRef(InspectorInstanceRef ref) {
    return highlightShowNode(valueToInspectorTreeNode[ref]);
  }

  bool highlightShowNode(InspectorTreeNode node) {
    if (node == null && parent != null) {
      // If nothing is highlighted, highlight the node selected in the parent
      // tree so user has context of where the node selected in the parent is
      // in the details tree.
      node = findMatchingInspectorTreeNode(parent.selectedDiagnostic);
    }

    currentShowNode = node;
    return true;
  }

  InspectorTreeNode findMatchingInspectorTreeNode(RemoteDiagnosticsNode node) {
    if (node?.valueRef == null) {
      return null;
    }
    return valueToInspectorTreeNode[node.valueRef];
  }

  Future<void> getPendingUpdateDone() async {
    // Wait for the selection to be resolved followed by waiting for the tree to be computed.
    await _selectionGroups?.pendingUpdateDone;
    await _treeGroups?.pendingUpdateDone;
    // TODO(jacobr): are there race conditions we need to think mroe carefully about here?
  }

  Future<void> refresh() {
    if (!visibleToUser) {
      // We will refresh again once we are visible.
      // There is a risk a refresh got triggered before the view was visble.
      return Future.value();
    }

    // TODO(jacobr): refresh the tree as well as just the properties.
    if (details != null) {
      return Future.wait(
          [getPendingUpdateDone(), details.getPendingUpdateDone()]);
    } else {
      return getPendingUpdateDone();
    }
  }

  // Note that this may be called after the controller is disposed.  We need to handle nulls in the fields.
  void shutdownTree(bool isolateStopped) {
    // It is critical we clear all data that is kept alive by inspector object
    // references in this method as that stale data will trigger inspector
    // exceptions.
    programaticSelectionChangeInProgress = true;
    _treeGroups?.clear(isolateStopped);
    _selectionGroups?.clear(isolateStopped);

    currentShowNode = null;
    _selectedNode.value = null;
    lastExpanded = null;

    subtreeRoot = null;

    inspectorTree?.root = inspectorTree?.createNode();
    programaticSelectionChangeInProgress = false;
    valueToInspectorTreeNode?.clear();
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
    await recomputeTreeRoot(null, null, false);
    if (_disposed) {
      return;
    }

    filterErrors();

    return getPendingUpdateDone();
  }

  void filterErrors() {
    if (isSummaryTree) {
      serviceManager.errorBadgeManager.filterErrors(InspectorScreen.id,
          (id) => hasDiagnosticsValue(InspectorInstanceRef(id)));
    }
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
    maybeLoadUI();
  }

  InspectorService get inspectorService => serviceManager.inspectorService;

  List<String> get rootDirectories =>
      _rootDirectories ?? parent.rootDirectories;
  List<String> _rootDirectories;

  Future<void> maybeLoadUI() async {
    if (parent != null) {
      // The parent controller will drive loading the UI.
      return;
    }
    if (!visibleToUser || !isActive) {
      return;
    }

    if (flutterAppFrameReady) {
      _rootDirectories = await inspectorService.inferPubRootDirectoryIfNeeded();
      if (_disposed) return;
      // We need to start by querying the inspector service to find out the
      // current state of the UI.

      final queryParams = loadQueryParams();
      final inspectorRef = queryParams.containsKey(inspectorRefQueryParam)
          ? queryParams[inspectorRefQueryParam]
          : null;
      await updateSelectionFromService(
          firstFrame: true, inspectorRef: inspectorRef);
    } else {
      final ready = await inspectorService.isWidgetTreeReady();
      if (_disposed) return;
      flutterAppFrameReady = ready;
      if (isActive && ready) {
        await maybeLoadUI();
      }
    }
  }

  Future<void> recomputeTreeRoot(
    RemoteDiagnosticsNode newSelection,
    RemoteDiagnosticsNode detailsSelection,
    bool setSubtreeRoot, {
    int subtreeDepth = 2,
  }) async {
    assert(!_disposed);
    if (_disposed) {
      return;
    }
    _treeGroups.cancelNext();
    try {
      final group = _treeGroups.next;
      final node = await (detailsSubtree
          ? group.getDetailsSubtree(subtreeRoot, subtreeDepth: subtreeDepth)
          : group.getRoot(treeType));
      if (node == null || group.disposed || _disposed) {
        return;
      }
      // TODO(jacobr): as a performance optimization we should check if the
      // new tree is identical to the existing tree in which case we should
      // dispose the new tree and keep the old tree.
      _treeGroups.promoteNext();
      clearValueToInspectorTreeNodeMapping();
      if (node != null) {
        final InspectorTreeNode rootNode = inspectorTree.setupInspectorTreeNode(
          inspectorTree.createNode(),
          node,
          expandChildren: true,
          expandProperties: false,
        );
        inspectorTree.root = rootNode;
      } else {
        inspectorTree.root = inspectorTree.createNode();
      }
      refreshSelection(newSelection, detailsSelection, setSubtreeRoot);
    } catch (error) {
      log(error.toString(), LogLevel.error);
      _treeGroups.cancelNext();
      return;
    }
  }

  void clearValueToInspectorTreeNodeMapping() {
    valueToInspectorTreeNode.clear();
  }

  /// Show the details subtree starting with node subtreeRoot highlighting
  /// node subtreeSelection.
  void showDetailSubtrees(
    RemoteDiagnosticsNode subtreeRoot,
    RemoteDiagnosticsNode subtreeSelection,
  ) {
    this.subtreeRoot = subtreeRoot;
    details?.setSubtreeRoot(subtreeRoot, subtreeSelection);
  }

  InspectorInstanceRef getSubtreeRootValue() {
    return subtreeRoot?.valueRef;
  }

  void setSubtreeRoot(
    RemoteDiagnosticsNode node,
    RemoteDiagnosticsNode selection,
  ) {
    assert(detailsSubtree);
    selection ??= node;
    if (node != null && node == subtreeRoot) {
      //  Select the new node in the existing subtree.
      applyNewSelection(selection, null, false);
      return;
    }
    subtreeRoot = node;
    if (node == null) {
      // Passing in a null node indicates we should clear the subtree and free any memory allocated.
      shutdownTree(false);
      return;
    }

    // Clear now to eliminate frame of highlighted nodes flicker.
    clearValueToInspectorTreeNodeMapping();
    recomputeTreeRoot(selection, null, false);
  }

  InspectorTreeNode getSubtreeRootNode() {
    if (subtreeRoot == null) {
      return null;
    }
    return valueToInspectorTreeNode[subtreeRoot.valueRef];
  }

  void refreshSelection(RemoteDiagnosticsNode newSelection,
      RemoteDiagnosticsNode detailsSelection, bool setSubtreeRoot) {
    newSelection ??= selectedDiagnostic;
    setSelectedNode(findMatchingInspectorTreeNode(newSelection));
    syncSelectionHelper(
      maybeRerootDetailsTree: setSubtreeRoot,
      selection: newSelection,
      detailsSelection: detailsSelection,
    );

    if (details != null) {
      if (subtreeRoot != null && getSubtreeRootNode() == null) {
        subtreeRoot = newSelection;
        details.setSubtreeRoot(newSelection, detailsSelection);
      }
    }
    syncTreeSelection();
  }

  void syncTreeSelection() {
    programaticSelectionChangeInProgress = true;
    inspectorTree.selection = selectedNode.value;
    inspectorTree.expandPath(selectedNode.value);
    programaticSelectionChangeInProgress = false;
    animateTo(selectedNode.value);
  }

  void selectAndShowNode(RemoteDiagnosticsNode node) {
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

  InspectorTreeNode getTreeNode(RemoteDiagnosticsNode node) {
    if (node == null) {
      return null;
    }
    return valueToInspectorTreeNode[node.valueRef];
  }

  void maybeUpdateValueUI(InspectorInstanceRef valueRef) {
    final node = valueToInspectorTreeNode[valueRef];
    if (node == null) {
      // The value isn't shown in the parent tree. Nothing to do.
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
      maybeLoadUI();
    }
    _refreshRateLimiter.scheduleRequest();
  }

  bool identicalDiagnosticsNodes(
    RemoteDiagnosticsNode a,
    RemoteDiagnosticsNode b,
  ) {
    if (a == b) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.dartDiagnosticRef == b.dartDiagnosticRef;
  }

  @override
  void onInspectorSelectionChanged() {
    if (!visibleToUser) {
      // Don't do anything. We will update the view once it is visible again.
      return;
    }
    if (detailsSubtree) {
      // Wait for the master to update.
      return;
    }
    updateSelectionFromService(firstFrame: false);
  }

  Future<void> updateSelectionFromService(
      {@required bool firstFrame, String inspectorRef}) async {
    if (parent != null) {
      // If we have a parent controller we should wait for the parent to update
      // our selection rather than updating it our self.
      return;
    }
    if (_selectionGroups == null) {
      // Already disposed. Ignore this requested to update selection.
      return;
    }
    treeLoadStarted = true;
    _selectionGroups.cancelNext();

    final group = _selectionGroups.next;

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
      isSummaryTree: isSummaryTree,
    );

    final Future<RemoteDiagnosticsNode> pendingDetailsFuture = isSummaryTree
        ? group.getSelection(selectedDiagnostic, treeType, isSummaryTree: false)
        : null;

    try {
      final RemoteDiagnosticsNode newSelection = await pendingSelectionFuture;
      if (_disposed || group.disposed) return;
      RemoteDiagnosticsNode detailsSelection;

      if (pendingDetailsFuture != null) {
        detailsSelection = await pendingDetailsFuture;
        if (_disposed || group.disposed) return;
      }

      if (!firstFrame &&
          detailsSelection?.valueRef == details?.selectedDiagnostic?.valueRef &&
          newSelection?.valueRef == selectedDiagnostic?.valueRef) {
        // No need to change the selection as it didn't actually change.
        _selectionGroups.cancelNext();
        return;
      }
      _selectionGroups.promoteNext();

      subtreeRoot = newSelection;

      applyNewSelection(newSelection, detailsSelection, true);
    } catch (error) {
      if (_selectionGroups.next == group) {
        log(error.toString(), LogLevel.error);
        _selectionGroups.cancelNext();
      }
    }
  }

  void applyNewSelection(
    RemoteDiagnosticsNode newSelection,
    RemoteDiagnosticsNode detailsSelection,
    bool setSubtreeRoot,
  ) {
    final InspectorTreeNode nodeInTree =
        findMatchingInspectorTreeNode(newSelection);

    if (nodeInTree == null) {
      // The tree has probably changed since we last updated. Do a full refresh
      // so that the tree includes the new node we care about.
      recomputeTreeRoot(newSelection, detailsSelection, setSubtreeRoot);
    }

    refreshSelection(newSelection, detailsSelection, setSubtreeRoot);
  }

  void animateTo(InspectorTreeNode node) {
    if (node == null) {
      return;
    }
    final List<InspectorTreeNode> targets = [node];

    // Backtrack to the the first non-property parent so that all properties
    // for the node are visible if one property is animated to. This is helpful
    // as typically users want to view the properties of a node as a chunk.
    while (node.parent != null && node.diagnostic?.isProperty == true) {
      node = node.parent;
    }
    // Make sure we scroll so that immediate un-expanded children
    // are also in view. There is no risk in including these children as
    // the amount of space they take up is bounded. This also ensures that if
    // a node is selected, its properties will also be selected as by
    // convention properties are the first children of a node and properties
    // typically do not have children and are never expanded by default.
    for (InspectorTreeNode child in node.children) {
      final RemoteDiagnosticsNode diagnosticsNode = child.diagnostic;
      targets.add(child);
      if (!child.isLeaf && child.isExpanded) {
        // Stop if we get to expanded children as they might be too large
        // to try to scroll into view.
        break;
      }
      if (diagnosticsNode != null && !diagnosticsNode.isProperty) {
        break;
      }
    }
    inspectorTree.animateToTargets(targets);
  }

  void setSelectedNode(InspectorTreeNode newSelection) {
    if (newSelection == selectedNode.value) {
      return;
    }

    _selectedNode.value = newSelection;

    lastExpanded = null; // New selected node takes precedence.
    endShowNode();
    if (details != null) {
      details.endShowNode();
    } else if (parent != null) {
      parent.endShowNode();
    }

    _updateSelectedErrorFromNode(_selectedNode.value);
    animateTo(selectedNode.value);
  }

  /// Update the index of the selected error based on a node that has been
  /// selected in the tree.
  void _updateSelectedErrorFromNode(InspectorTreeNode node) {
    final inspectorRef = node?.diagnostic?.valueRef?.id;

    final errors = serviceManager.errorBadgeManager
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
      serviceManager.errorBadgeManager
          .markErrorAsRead(InspectorScreen.id, errors[inspectorRef]);
      // Also clear the error badge since new errors may have arrived while
      // the inspector was visible (normally they're cleared when visiting
      // the screen) and visiting an errored node seems an appropriate
      // acknowledgement of the errors.
      serviceManager.errorBadgeManager.clearErrors(InspectorScreen.id);
    }
  }

  /// Updates the index of the selected error and selects its node in the tree.
  void selectErrorByIndex(int index) {
    _selectedErrorIndex.value = index;

    if (index == null) return;

    final errors = serviceManager.errorBadgeManager
        .erroredItemsForPage(InspectorScreen.id)
        .value;

    updateSelectionFromService(
        firstFrame: false, inspectorRef: errors.keys.elementAt(index));
  }

  void _onExpand(InspectorTreeNode node) {
    inspectorTree.maybePopulateChildren(node);
  }

  Future<void> _addNodeToConsole(InspectorTreeNode node) async {
    final valueRef = node.diagnostic.valueRef;
    if (valueRef != null) {
      final isolateRef = inspectorService.isolateRef;
      final instanceRef = await node.diagnostic.inspectorService
          ?.toObservatoryInstanceRef(valueRef);
      if (_disposed) return;

      if (instanceRef != null) {
        serviceManager.consoleService.appendInstanceRef(
          value: instanceRef,
          diagnostic: node.diagnostic,
          isolateRef: isolateRef,
          forceScrollIntoView: true,
        );
      }
    }
  }

  void selectionChanged() {
    if (visibleToUser == false) {
      return;
    }

    final InspectorTreeNode node = inspectorTree.selection;
    if (node != null) {
      inspectorTree.maybePopulateChildren(node);
    }
    if (programaticSelectionChangeInProgress) {
      return;
    }
    if (node != null) {
      setSelectedNode(node);
      unawaited(_addNodeToConsole(node));

      // Don't reroot if the selected value is already visible in the details tree.
      final bool maybeReroot = isSummaryTree &&
          details != null &&
          selectedDiagnostic != null &&
          !details.hasDiagnosticsValue(selectedDiagnostic.valueRef);
      syncSelectionHelper(
        maybeRerootDetailsTree: maybeReroot,
        selection: selectedDiagnostic,
        detailsSelection: selectedDiagnostic,
      );

      if (!maybeReroot) {
        if (isSummaryTree && details != null) {
          details.selectAndShowNode(selectedDiagnostic);
        } else if (parent != null) {
          parent
              .selectAndShowNode(firstAncestorInParentTree(selectedNode.value));
        }
      }
    }
  }

  RemoteDiagnosticsNode firstAncestorInParentTree(InspectorTreeNode node) {
    if (parent == null) {
      return node.diagnostic;
    }
    while (node != null) {
      final diagnostic = node.diagnostic;
      if (diagnostic != null &&
          parent.hasDiagnosticsValue(diagnostic.valueRef)) {
        return parent.findDiagnosticsValue(diagnostic.valueRef);
      }
      node = node.parent;
    }
    return null;
  }

  void syncSelectionHelper({
    @required bool maybeRerootDetailsTree,
    @required RemoteDiagnosticsNode selection,
    @required RemoteDiagnosticsNode detailsSelection,
  }) {
    if (selection != null) {
      if (selection.isCreatedByLocalProject) {
        _navigateTo(selection);
      }
    }
    if (detailsSubtree || details == null) {
      if (selection != null) {
        var toSelect = selectedNode.value;

        while (toSelect != null && toSelect.diagnostic.isProperty) {
          toSelect = toSelect.parent;
        }

        if (toSelect != null) {
          final diagnosticToSelect = toSelect.diagnostic;
          diagnosticToSelect.setSelectionInspector(true);
        }
      }
    }

    if (maybeRerootDetailsTree) {
      showDetailSubtrees(selection, detailsSelection);
    } else if (selection != null) {
      // We can't rely on the details tree to update the selection on the server in this case.
      selection.setSelectionInspector(true);
    }
  }

  void _navigateTo(RemoteDiagnosticsNode diagnostic) {
    // TODO(jacobr): dispatch an event over the inspectorService requesting a
    //  navigate operation.
  }

  @override
  void dispose() {
    assert(!_disposed);
    _disposed = true;
    if (inspectorService != null) {
      shutdownTree(false);
    }
    _treeGroups?.clear(false);
    _treeGroups = null;
    _selectionGroups?.clear(false);
    _selectionGroups = null;
    details?.dispose();
    super.dispose();
  }

  static String treeTypeDisplayName(FlutterTreeType treeType) {
    switch (treeType) {
      case FlutterTreeType.widget:
        return 'Widget';
      case FlutterTreeType.renderObject:
        return 'Render Objects';
      default:
        return null;
    }
  }

  void _onNodeAdded(
    InspectorTreeNode node,
    RemoteDiagnosticsNode diagnosticsNode,
  ) {
    final InspectorInstanceRef valueRef = diagnosticsNode.valueRef;
    // Properties do not have unique values so should not go in the valueToInspectorTreeNode map.
    if (valueRef.id != null && !diagnosticsNode.isProperty) {
      valueToInspectorTreeNode[valueRef] = node;
    }
  }

  Future<void> expandAllNodesInDetailsTree() async {
    await details.recomputeTreeRoot(
      inspectorTree.selection?.diagnostic,
      details.inspectorTree.selection?.diagnostic ??
          details.inspectorTree.root?.diagnostic,
      false,
      subtreeDepth: maxJsInt,
    );
  }

  Future<void> collapseDetailsToSelected() async {
    details.inspectorTree.collapseToSelected();
    details.animateTo(details.inspectorTree.selection);
  }

  /// execute given [callback] when minimum Flutter [version] is met.
  void _onVersionSupported(
    SemanticVersion version,
    VoidCallback callback,
  ) {
    final flutterVersionServiceListenable = serviceManager
        .registeredServiceListenable(registrations.flutterVersion.service);
    addAutoDisposeListener(flutterVersionServiceListenable, () async {
      final registered = flutterVersionServiceListenable.value;
      if (registered) {
        final flutterVersion =
            FlutterVersion.parse((await serviceManager.flutterVersion).json);
        if (_disposed) return;
        if (flutterVersion.isSupported(supportedVersion: version)) {
          callback();
        }
      }
    });
  }

  void _checkForExpandCollapseSupport() {
    if (onExpandCollapseSupported == null) return;
    // Configurable subtree depth is available in versions of Flutter
    // greater than or equal to 1.9.7, but the flutterVersion service is
    // not available until 1.10.1, so we will check for 1.10.1 here.
    _onVersionSupported(
      SemanticVersion(major: 1, minor: 10, patch: 1),
      onExpandCollapseSupported,
    );
  }

  void _checkForLayoutExplorerSupport() {
    if (onLayoutExplorerSupported == null) return;
    _onVersionSupported(
      SemanticVersion(major: 1, minor: 13, patch: 1),
      onLayoutExplorerSupported,
    );
  }
}
