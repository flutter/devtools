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

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../globals.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../utils.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';
import 'inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_tree.dart';

void _logError(error) {
  print(error);
}

TextStyle textStyleForLevel(DiagnosticLevel level) {
  switch (level) {
    case DiagnosticLevel.hidden:
      return inspector_text_styles.grayed;
    case DiagnosticLevel.warning:
      return inspector_text_styles.warning;
    case DiagnosticLevel.error:
      return inspector_text_styles.error;
    case DiagnosticLevel.debug:
    case DiagnosticLevel.info:
    case DiagnosticLevel.fine:
    default:
      return inspector_text_styles.regular;
  }
}

/// This class is based on the InspectorPanel class from the Flutter IntelliJ
/// plugin with some refactors to make it more of a true controller than a view.
///
/// No changes to this class are allowed to pull in dependencies on dart:html.
class InspectorController implements InspectorServiceClient {
  InspectorController({
    @required this.inspectorService,
    @required InspectorTreeFactory inspectorTreeFactory,
    @required this.treeType,
    this.parent,
    this.isSummaryTree = true,
  })  : _treeGroups = InspectorObjectGroupManager(inspectorService, 'tree'),
        _selectionGroups =
            InspectorObjectGroupManager(inspectorService, 'selection') {
    _refreshRateLimiter = RateLimiter(refreshFramesPerSecond, refresh);

    inspectorTree = inspectorTreeFactory(
      summaryTree: isSummaryTree,
      treeType: treeType,
      onNodeAdded: _onNodeAdded,
      onHover: highlightShowNode,
      onSelectionChange: selectionChanged,
      onExpand: _onExpand,
    );
    if (isSummaryTree) {
      details = InspectorController(
        inspectorService: inspectorService,
        inspectorTreeFactory: inspectorTreeFactory,
        treeType: treeType,
        parent: this,
        isSummaryTree: false,
      );
    } else {
      details = null;
    }

    flutterIsolateSubscription = serviceManager.isolateManager
        .getSelectedIsolate((IsolateRef flutterIsolate) {
      if (flutterIsolate == null) {
        onIsolateStopped();
      }
    });
  }

  /// Maximum frame rate to refresh the inspector at to avoid taxing the
  /// physical device with too many requests to recompute properties and trees.
  ///
  /// A value up to around 30 frames per second could be reasonable for
  /// debugging highly interactive cases particularly when the user is on a
  /// simulator or high powered native device. The frame rate is set low
  /// for now mainly to minimize risk.
  static const double refreshFramesPerSecond = 5.0;

  final bool isSummaryTree;

  /// Parent InspectorController if this is a details subtree.
  InspectorController parent;
  InspectorController details;
  InspectorTree inspectorTree;
  final FlutterTreeType treeType;
  final InspectorService inspectorService;
  StreamSubscription<IsolateRef> flutterIsolateSubscription;

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

  InspectorTreeNode selectedNode;
  InspectorTreeNode lastExpanded;
  bool isActive = false;
  final Map<InspectorInstanceRef, InspectorTreeNode> valueToInspectorTreeNode =
      {};

  /// When visibleToUser is false we should dispose all allocated objects and
  /// not perform any actions.
  bool visibleToUser = false;
  bool highlightNodesShownInBothTrees = false;

  bool get detailsSubtree => parent != null;

  RemoteDiagnosticsNode get selectedDiagnostic => selectedNode?.diagnostic;

  FlutterTreeType getTreeType() {
    return treeType;
  }

  void setVisibleToUser(bool visible) {
    if (visibleToUser == visible) {
      return;
    }
    visibleToUser = visible;
    details?.setVisibleToUser(visible);

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
    await _selectionGroups.pendingUpdateDone;
    await _treeGroups.pendingUpdateDone;
    // TODO(jacobr): are there race conditions we need to think mroe carefully about here?
  }

  Future<void> refresh() {
    if (!visibleToUser) {
      // We will refresh again once we are visible.
      // There is a risk a refresh got triggered before the view was visble.
      return Future.value(null);
    }

    // TODO(jacobr): refresh the tree as well as just the properties.
    if (details != null) {
      return Future.wait(
          [getPendingUpdateDone(), details.getPendingUpdateDone()]);
    } else {
      return getPendingUpdateDone();
    }
  }

  void shutdownTree(bool isolateStopped) {
    // It is critical we clear all data that is kept alive by inspector object
    // references in this method as that stale data will trigger inspector
    // exceptions.
    programaticSelectionChangeInProgress = true;
    _treeGroups.clear(isolateStopped);
    _selectionGroups.clear(isolateStopped);

    currentShowNode = null;
    selectedNode = null;
    lastExpanded = null;

    selectedNode = null;
    subtreeRoot = null;

    inspectorTree.root = inspectorTree.createNode();
    details?.shutdownTree(isolateStopped);
    programaticSelectionChangeInProgress = false;
    valueToInspectorTreeNode.clear();
  }

  void onIsolateStopped() {
    flutterAppFrameReady = false;
    treeLoadStarted = false;
    shutdownTree(true);
  }

  @override
  Future<void> onForceRefresh() {
    assert(!_disposed);
    if (!visibleToUser || _disposed) {
      return Future.value(null);
    }
    recomputeTreeRoot(null, null, false);

    return getPendingUpdateDone();
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

  Future<void> maybeLoadUI() async {
    if (!visibleToUser || !isActive) {
      return;
    }

    if (flutterAppFrameReady) {
      // We need to start by querying the inspector service to find out the
      // current state of the UI.
      await updateSelectionFromService();
    } else {
      final ready = await inspectorService.isWidgetTreeReady();
      flutterAppFrameReady = ready;
      if (isActive && ready) {
        await maybeLoadUI();
      }
    }
  }

  Future<void> recomputeTreeRoot(RemoteDiagnosticsNode newSelection,
      RemoteDiagnosticsNode detailsSelection, bool setSubtreeRoot) async {
    assert(!_disposed);
    if (_disposed) {
      return;
    }
    _treeGroups.cancelNext();
    try {
      final group = _treeGroups.next;
      final node = await (detailsSubtree
          ? group.getDetailsSubtree(subtreeRoot)
          : group.getRoot(treeType));
      if (node == null || group.disposed) {
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
      _logError(error);
      _treeGroups.cancelNext();
      return;
    }
  }

  void clearValueToInspectorTreeNodeMapping() {
    if (parent != null) {
      valueToInspectorTreeNode.keys.forEach(parent.maybeUpdateValueUI);
    }
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
    syncSelectionHelper(setSubtreeRoot, detailsSelection);

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
    inspectorTree.selection = selectedNode;
    programaticSelectionChangeInProgress = false;
    animateTo(selectedNode);
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
    updateSelectionFromService();
  }

  Future<void> updateSelectionFromService() async {
    final bool firstFrame = !treeLoadStarted;
    treeLoadStarted = true;
    _selectionGroups.cancelNext();

    final group = _selectionGroups.next;
    final pendingSelectionFuture =
        group.getSelection(selectedDiagnostic, treeType, isSummaryTree);

    final Future<RemoteDiagnosticsNode> pendingDetailsFuture = isSummaryTree
        ? group.getSelection(selectedDiagnostic, treeType, false)
        : null;

    try {
      final RemoteDiagnosticsNode newSelection = await pendingSelectionFuture;
      if (group.disposed) return;
      RemoteDiagnosticsNode detailsSelection;

      if (pendingDetailsFuture != null) {
        detailsSelection = await pendingDetailsFuture;
        if (group.disposed) return;
      }

      if (!firstFrame &&
          detailsSelection?.valueRef == details.selectedDiagnostic?.valueRef &&
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
        _logError(error);
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
      if (!child.isLeaf && child.expanded) {
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
    if (newSelection == selectedNode) {
      return;
    }
    if (selectedNode != null) {
      if (!detailsSubtree) {
        inspectorTree.nodeChanged(selectedNode.parent);
      }
    }
    selectedNode = newSelection;

    lastExpanded = null; // New selected node takes precedence.
    endShowNode();
    if (details != null) {
      details.endShowNode();
    } else if (parent != null) {
      parent.endShowNode();
    }

    animateTo(selectedNode);
  }

  void _onExpand(InspectorTreeNode node) {
    inspectorTree.maybePopulateChildren(node);
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

      // Don't reroot if the selected value is already visible in the details tree.
      final bool maybeReroot = isSummaryTree &&
          details != null &&
          selectedDiagnostic != null &&
          !details.hasDiagnosticsValue(selectedDiagnostic.valueRef);
      syncSelectionHelper(maybeReroot, null);
      if (maybeReroot == false) {
        if (isSummaryTree && details != null) {
          details.selectAndShowNode(selectedDiagnostic);
        } else if (parent != null) {
          parent.selectAndShowNode(firstAncestorInParentTree(selectedNode));
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

  void syncSelectionHelper(
      bool maybeRerootDetailsTree, RemoteDiagnosticsNode detailsSelection) {
    if (!detailsSubtree && selectedNode != null) {
      inspectorTree.nodeChanged(selectedNode.parent);
    }
    final RemoteDiagnosticsNode diagnostic = selectedDiagnostic;
    if (diagnostic != null) {
      if (diagnostic.isCreatedByLocalProject) {
        _navigateTo(diagnostic);
      }
    }
    if (detailsSubtree || details == null) {
      if (diagnostic != null) {
        var toSelect = selectedNode;

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
      showDetailSubtrees(diagnostic, detailsSelection);
    } else if (diagnostic != null) {
      // We can't rely on the details tree to update the selection on the server in this case.
      final selection = detailsSelection ?? diagnostic;
      selection.setSelectionInspector(true);
    }
  }

  void _navigateTo(RemoteDiagnosticsNode diagnostic) {
    // TODO(jacobr): dispatch an event over the inspectorService requesting a
    //  navigate operation.
  }

  void dispose() {
    assert(!_disposed);
    _disposed = true;
    flutterIsolateSubscription.cancel();
    if (inspectorService != null) {
      shutdownTree(false);
    }
    _treeGroups = null;
    _selectionGroups = null;
    details?.dispose();
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
    parent?.maybeUpdateValueUI(valueRef);
  }
}
