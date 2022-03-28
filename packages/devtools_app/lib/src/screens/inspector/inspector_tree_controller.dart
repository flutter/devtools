// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

library inspector_tree;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/logger/logger.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/collapsible_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/error_badge_manager.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import '../../ui/colors.dart';
import '../../ui/search.dart';
import '../../ui/utils.dart';
import '../debugger/debugger_controller.dart';
import 'diagnostics.dart';
import 'diagnostics_node.dart';
import 'inspector_breadcrumbs.dart';
import 'inspector_text_styles.dart' as inspector_text_styles;
import 'inspector_tree.dart';

/// Presents a [TreeNode].
class _InspectorTreeRowWidget extends StatefulWidget {
  /// Constructs a [_InspectorTreeRowWidget] that presents a line in the
  /// Inspector tree.
  const _InspectorTreeRowWidget({
    required Key key,
    required this.row,
    required this.inspectorTreeState,
    this.error,
    required this.scrollControllerX,
    required this.viewportWidth,
    required this.debuggerController,
  }) : super(key: key);

  final _InspectorTreeState inspectorTreeState;

  InspectorTreeNode get node => row.node;
  final InspectorTreeRow row;
  final DebuggerController debuggerController;
  final ScrollController scrollControllerX;
  final double viewportWidth;

  /// A [DevToolsError] that applies to the widget in this row.
  ///
  /// This will be null if there is no error for this row.
  final DevToolsError? error;

  @override
  _InspectorTreeRowState createState() => _InspectorTreeRowState();
}

class _InspectorTreeRowState extends State<_InspectorTreeRowWidget>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: InspectorRowContent(
        row: widget.row,
        error: widget.error,
        expandArrowAnimation: expandArrowAnimation,
        controller: widget.inspectorTreeState.controller,
        scrollControllerX: widget.scrollControllerX,
        viewportWidth: widget.viewportWidth,
        onToggle: () {
          setExpanded(!isExpanded);
        },
        debuggerController: widget.debuggerController,
      ),
    );
  }

  @override
  bool get isExpanded => widget.node.isExpanded;

  @override
  void onExpandChanged(bool expanded) {
    setState(() {
      final row = widget.row;
      if (expanded) {
        widget.inspectorTreeState.controller!.onExpandRow(row);
      } else {
        widget.inspectorTreeState.controller!.onCollapseRow(row);
      }
    });
  }

  @override
  bool shouldShow() => widget.node.shouldShow!;
}

class InspectorTreeController extends Object
    with SearchControllerMixin<InspectorTreeRow> {
  /// Clients the controller notifies to trigger changes to the UI.
  final Set<InspectorControllerClient> _clients = {};

  InspectorTreeNode createNode() => InspectorTreeNode();

  SearchTargetType _searchTarget = SearchTargetType.widget;

  void addClient(InspectorControllerClient value) {
    final firstClient = _clients.isEmpty;
    _clients.add(value);
    if (firstClient) {
      config!.onClientActiveChange?.call(true);
    }
  }

  void removeClient(InspectorControllerClient value) {
    _clients.remove(value);
    if (_clients.isEmpty) {
      config!.onClientActiveChange?.call(false);
    }
  }

  // Method defined to avoid a direct Flutter dependency.
  void setState(VoidCallback fn) {
    fn();
    for (var client in _clients) {
      client.onChanged();
    }
  }

  void requestFocus() {
    for (var client in _clients) {
      client.requestFocus();
    }
  }

  InspectorTreeNode? get root => _root;
  InspectorTreeNode? _root;

  set root(InspectorTreeNode? node) {
    setState(() {
      _root = node;
      _populateSearchableCachedRows();
    });
  }

  RemoteDiagnosticsNode? subtreeRoot; // Optional.

  InspectorTreeNode? get selection => _selection;
  InspectorTreeNode? _selection;

  InspectorTreeConfig? get config => _config;
  InspectorTreeConfig? _config;

  set config(InspectorTreeConfig? value) {
    // Only allow setting config once.
    assert(_config == null);
    _config = value;
  }

  set selection(InspectorTreeNode? node) {
    if (node == _selection) return;

    setState(() {
      _selection?.selected = false;
      _selection = node;
      _selection?.selected = true;
      if (config!.onSelectionChange != null) {
        config!.onSelectionChange!();
      }
    });
  }

  InspectorTreeNode? get hover => _hover;
  InspectorTreeNode? _hover;

  double? lastContentWidth;

  final List<InspectorTreeRow?> cachedRows = [];
  InspectorTreeRow? _cachedSelectedRow;

  /// All cached rows of the tree.
  ///
  /// Similar to [cachedRows] but:
  /// * contains every row in the tree (including collapsed rows)
  /// * items don't change when nodes are expanded or collapsed
  /// * items are populated only when root is changed
  final _searchableCachedRows = <InspectorTreeRow?>[];

  void setSearchTarget(SearchTargetType searchTarget) {
    _searchTarget = searchTarget;
    refreshSearchMatches();
  }

  // TODO: we should add a listener instead that clears the cache when the
  // root is marked as dirty.
  void _maybeClearCache() {
    if (root != null && root!.isDirty) {
      cachedRows.clear();
      _cachedSelectedRow = null;
      root!.isDirty = false;
      lastContentWidth = null;
    }
  }

  void _populateSearchableCachedRows() {
    _searchableCachedRows.clear();
    for (int i = 0; i < numRows; i++) {
      _searchableCachedRows.add(getCachedRow(i));
    }
  }

  InspectorTreeRow? getCachedRow(int index) {
    if (index < 0) return null;

    _maybeClearCache();
    while (cachedRows.length <= index) {
      cachedRows.add(null);
    }
    cachedRows[index] ??= root?.getRow(index);

    final cachedRow = cachedRows[index];
    cachedRow?.isSearchMatch =
        _searchableCachedRows.safeGet(index)?.isSearchMatch ?? false;

    if (cachedRow?.isSelected == true) {
      _cachedSelectedRow = cachedRow;
    }
    return cachedRow;
  }

  double getRowOffset(int index) {
    return (getCachedRow(index)?.depth ?? 0) * columnWidth;
  }

  List<InspectorTreeNode> getPathFromSelectedRowToRoot() {
    final selectedItem = _cachedSelectedRow?.node;
    if (selectedItem == null) return [];

    final pathToRoot = <InspectorTreeNode>[selectedItem];
    InspectorTreeNode? nextParentNode = selectedItem.parent;
    while (nextParentNode != null) {
      pathToRoot.add(nextParentNode);
      nextParentNode = nextParentNode.parent;
    }
    return pathToRoot.reversed.toList();
  }

  set hover(InspectorTreeNode? node) {
    if (node == _hover) {
      return;
    }
    setState(() {
      _hover = node;
      // TODO(jacobr): we could choose to repaint only a portion of the UI
    });
  }

  void navigateUp() {
    _navigateHelper(-1);
  }

  void navigateDown() {
    _navigateHelper(1);
  }

  void navigateLeft() {
    // This logic is consistent with how IntelliJ handles tree navigation on
    // on left arrow key press.
    if (selection == null) {
      _navigateHelper(-1);
      return;
    }

    if (selection!.isExpanded) {
      setState(() {
        selection!.isExpanded = false;
      });
      return;
    }
    if (selection!.parent != null) {
      selection = selection!.parent;
    }
  }

  void navigateRight() {
    // This logic is consistent with how IntelliJ handles tree navigation on
    // on right arrow key press.

    if (selection == null || selection!.isExpanded) {
      _navigateHelper(1);
      return;
    }

    setState(() {
      selection!.isExpanded = true;
    });
  }

  void _navigateHelper(int indexOffset) {
    if (numRows == 0) return;

    if (selection == null) {
      selection = root;
      return;
    }

    selection = root!
        .getRow(
            (root!.getRowIndex(selection) + indexOffset).clamp(0, numRows - 1))
        ?.node;
  }

  double get horizontalPadding => 10.0;

  double getDepthIndent(int depth) {
    return (depth + 1) * columnWidth + horizontalPadding;
  }

  double getRowY(int index) {
    return rowHeight * index + verticalPadding;
  }

  void nodeChanged(InspectorTreeNode node) {
    setState(() {
      node.isDirty = true;
    });
  }

  void removeNodeFromParent(InspectorTreeNode node) {
    setState(() {
      node.parent?.removeChild(node);
    });
  }

  void appendChild(InspectorTreeNode node, InspectorTreeNode child) {
    setState(() {
      node.appendChild(child);
    });
  }

  void expandPath(InspectorTreeNode? node) {
    setState(() {
      _expandPath(node);
    });
  }

  void _expandPath(InspectorTreeNode? node) {
    while (node != null) {
      if (!node.isExpanded) {
        node.isExpanded = true;
      }
      node = node.parent;
    }
  }

  void collapseToSelected() {
    setState(() {
      _collapseAllNodes(root!);
      if (selection == null) return;
      _expandPath(selection);
    });
  }

  void _collapseAllNodes(InspectorTreeNode root) {
    root.isExpanded = false;
    root.children.forEach(_collapseAllNodes);
  }

  int get numRows => root != null ? root!.subtreeSize : 0;

  int getRowIndex(double y) => max(0, (y - verticalPadding) ~/ rowHeight);

  InspectorTreeRow? getRowForNode(InspectorTreeNode node) {
    return getCachedRow(root!.getRowIndex(node));
  }

  InspectorTreeRow? getRow(Offset offset) {
    if (root == null) return null;
    final int row = getRowIndex(offset.dy);
    return row < root!.subtreeSize ? getCachedRow(row) : null;
  }

  void onExpandRow(InspectorTreeRow row) {
    setState(() {
      row.node.isExpanded = true;
      if (config!.onExpand != null) {
        config!.onExpand!(row.node);
      }
    });
  }

  void onCollapseRow(InspectorTreeRow row) {
    setState(() {
      row.node.isExpanded = false;
    });
  }

  void onSelectRow(InspectorTreeRow row) {
    onSelectNode(row.node);
  }

  void onSelectNode(InspectorTreeNode? node) {
    selection = node;
    ga.select(
      analytics_constants.inspector,
      analytics_constants.treeNodeSelection,
    );
    expandPath(node);
  }

  Rect getBoundingBox(InspectorTreeRow row) {
    // For future reference: the bounding box likely needs to be in terms of
    // positions after the current animations are complete so that computations
    // to start animations to show specific widget scroll to where the target
    // nodes will be displayed rather than where they are currently displayed.
    return Rect.fromLTWH(
      getDepthIndent(row.depth),
      getRowY(row.index),
      rowWidth,
      rowHeight,
    );
  }

  void scrollToRect(Rect targetRect) {
    for (var client in _clients) {
      client.scrollToRect(targetRect);
    }
  }

  /// Width each row in the tree should have ignoring its indent.
  ///
  /// Content in rows should wrap if it exceeds this width.
  final double rowWidth = 1200;

  /// Maximum indent of the tree in pixels.
  double? _maxIndent;

  double? get maxRowIndent {
    if (lastContentWidth == null) {
      double maxIndent = 0;
      for (int i = 0; i < numRows; i++) {
        final row = getCachedRow(i);
        if (row != null) {
          maxIndent = max(maxIndent, getDepthIndent(row.depth));
        }
      }
      lastContentWidth = maxIndent + maxIndent;
      _maxIndent = maxIndent;
    }
    return _maxIndent;
  }

  void animateToTargets(List<InspectorTreeNode> targets) {
    Rect? targetRect;

    for (InspectorTreeNode target in targets) {
      final row = getRowForNode(target);
      if (row != null) {
        final rowRect = getBoundingBox(row);
        targetRect =
            targetRect == null ? rowRect : targetRect.expandToInclude(rowRect);
      }
    }

    if (targetRect == null || targetRect.isEmpty) return;

    targetRect = targetRect.inflate(20.0);
    scrollToRect(targetRect);
  }

  bool expandPropertiesByDefault(DiagnosticsTreeStyle style) {
    // This code matches the text style defaults for which styles are
    //  by default and which aren't.
    switch (style) {
      case DiagnosticsTreeStyle.none:
      case DiagnosticsTreeStyle.singleLine:
      case DiagnosticsTreeStyle.errorProperty:
        return false;

      case DiagnosticsTreeStyle.sparse:
      case DiagnosticsTreeStyle.offstage:
      case DiagnosticsTreeStyle.dense:
      case DiagnosticsTreeStyle.transition:
      case DiagnosticsTreeStyle.error:
      case DiagnosticsTreeStyle.whitespace:
      case DiagnosticsTreeStyle.flat:
      case DiagnosticsTreeStyle.shallow:
      case DiagnosticsTreeStyle.truncateChildren:
        return true;
    }
  }

  InspectorTreeNode setupInspectorTreeNode(
    InspectorTreeNode node,
    RemoteDiagnosticsNode diagnosticsNode, {
    required bool expandChildren,
    required bool expandProperties,
  }) {
    node.diagnostic = diagnosticsNode;
    if (config!.onNodeAdded != null) {
      config!.onNodeAdded!(node, diagnosticsNode);
    }

    if (diagnosticsNode.hasChildren ||
        diagnosticsNode.inlineProperties.isNotEmpty) {
      if (diagnosticsNode.childrenReady || !diagnosticsNode.hasChildren) {
        final bool styleIsMultiline =
            expandPropertiesByDefault(diagnosticsNode.style);
        setupChildren(
          diagnosticsNode,
          node,
          node.diagnostic!.childrenNow,
          expandChildren: expandChildren && styleIsMultiline,
          expandProperties: expandProperties && styleIsMultiline,
        );
      } else {
        node.clearChildren();
        node.appendChild(createNode());
      }
    }
    return node;
  }

  void setupChildren(
    RemoteDiagnosticsNode parent,
    InspectorTreeNode treeNode,
    List<RemoteDiagnosticsNode>? children, {
    required bool expandChildren,
    required bool expandProperties,
  }) {
    treeNode.isExpanded = expandChildren;
    if (treeNode.children.isNotEmpty) {
      // Only case supported is this is the loading node.
      assert(treeNode.children.length == 1);
      removeNodeFromParent(treeNode.children.first);
    }
    final inlineProperties = parent.inlineProperties;

    for (RemoteDiagnosticsNode property in inlineProperties) {
      appendChild(
        treeNode,
        setupInspectorTreeNode(
          createNode(),
          property,
          // We are inside a property so only expand children if
          // expandProperties is true.
          expandChildren: expandProperties,
          expandProperties: expandProperties,
        ),
      );
    }
    if (children != null) {
      for (RemoteDiagnosticsNode child in children) {
        appendChild(
          treeNode,
          setupInspectorTreeNode(
            createNode(),
            child,
            expandChildren: expandChildren,
            expandProperties: expandProperties,
          ),
        );
      }
    }
  }

  Future<void> maybePopulateChildren(InspectorTreeNode treeNode) async {
    final RemoteDiagnosticsNode? diagnostic = treeNode.diagnostic;
    if (diagnostic != null &&
        diagnostic.hasChildren &&
        (treeNode.hasPlaceholderChildren || treeNode.children.isEmpty)) {
      try {
        final children = await diagnostic.children;
        if (treeNode.hasPlaceholderChildren || treeNode.children.isEmpty) {
          setupChildren(
            diagnostic,
            treeNode,
            children,
            expandChildren: true,
            expandProperties: false,
          );
          nodeChanged(treeNode);
          if (treeNode == selection) {
            expandPath(treeNode);
          }
        }
      } catch (e) {
        log(e.toString(), LogLevel.error);
      }
    }
  }

  /* Search support */
  @override
  void onMatchChanged(int index) {
    onSelectRow(searchMatches.value[index]);
  }

  @override
  Duration get debounceDelay => const Duration(milliseconds: 300);

  void dispose() {
    disposeSearch();
  }

  @override
  List<InspectorTreeRow> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    final matches = <InspectorTreeRow>[];

    if (searchPreviousMatches) {
      final List<InspectorTreeRow> previousMatches = searchMatches.value;
      for (final previousMatch in previousMatches) {
        if (previousMatch.node.diagnostic!.searchValue
            .caseInsensitiveContains(search)) {
          matches.add(previousMatch);
        }
      }

      if (matches.isNotEmpty) return matches;
    }

    int _debugStatsSearchOps = 0;
    final _debugStatsWidgets = _searchableCachedRows.length;

    if (search.isEmpty ||
        serviceManager.inspectorService == null ||
        serviceManager.inspectorService!.isDisposed) {
      assert(() {
        debugPrint('Search completed, no search');
        return true;
      }());
      return matches;
    }

    assert(() {
      debugPrint('Search started: ' + _searchTarget.toString());
      return true;
    }());

    for (final row in _searchableCachedRows) {
      final diagnostic = row!.node.diagnostic;
      if (diagnostic == null) continue;

      // Widget search begin
      if (_searchTarget == SearchTargetType.widget) {
        _debugStatsSearchOps++;
        if (diagnostic.searchValue.caseInsensitiveContains(search)) {
          matches.add(row);
          continue;
        }
      }
      // Widget search end
    }

    assert(() {
      debugPrint('Search completed with ' +
          _debugStatsWidgets.toString() +
          ' widgets, ' +
          _debugStatsSearchOps.toString() +
          ' ops');
      return true;
    }());

    return matches;
  }
}

extension RemoteDiagnosticsNodeExtension on RemoteDiagnosticsNode {
  String get searchValue {
    final description = toStringShort();
    final textPreview = json['textPreview'];
    return textPreview is String
        ? '$description ${textPreview.replaceAll('\n', ' ')}'
        : description;
  }
}

abstract class InspectorControllerClient {
  void onChanged();

  void scrollToRect(Rect? rect);

  void requestFocus();
}

class InspectorTree extends StatefulWidget {
  const InspectorTree({
    Key? key,
    required this.controller,
    required this.debuggerController,
    this.inspectorTreeController,
    this.isSummaryTree = false,
    this.widgetErrors,
  })  : assert(isSummaryTree == (inspectorTreeController == null)),
        super(key: key);

  final InspectorTreeController? controller;
  final InspectorTreeController? inspectorTreeController;
  final DebuggerController debuggerController;
  final bool isSummaryTree;
  final LinkedHashMap<String, InspectableWidgetError>? widgetErrors;

  @override
  State<InspectorTree> createState() => _InspectorTreeState();
}

// AutomaticKeepAlive is necessary so that the tree does not get recreated when we switch tabs.
class _InspectorTreeState extends State<InspectorTree>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<InspectorTree>,
        AutoDisposeMixin
    implements InspectorControllerClient {
  InspectorTreeController? get controller => widget.controller;

  bool get _isSummaryTree => widget.isSummaryTree;

  late ScrollController _scrollControllerY;
  late ScrollController _scrollControllerX;
  Future<void>? _currentAnimateY;
  Rect? _currentAnimateTarget;

  AnimationController? _constraintDisplayController;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController();
    _scrollControllerY = ScrollController();
    // TODO(devoncarew): Commented out as per flutter/devtools/pull/2001.
    //_scrollControllerY.addListener(_onScrollYChange);
    if (_isSummaryTree) {
      _constraintDisplayController = longAnimationController(this);
    }
    _focusNode = FocusNode(debugLabel: 'inspector-tree');
    autoDisposeFocusNode(_focusNode);
    _bindToController();
  }

  @override
  void didUpdateWidget(InspectorTree oldWidget) {
    if (oldWidget.controller != widget.controller) {
      final InspectorTreeController? oldController = oldWidget.controller;
      oldController?.removeClient(this);

      // TODO(elliette): Figure out if we can remove this. See explanation:
      // https://github.com/flutter/devtools/pull/1290/files#r342399899.
      cancelListeners();

      _bindToController();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    controller?.removeClient(this);
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    _constraintDisplayController?.dispose();
  }

  @override
  void requestFocus() {
    _focusNode!.requestFocus();
  }

  // TODO(devoncarew): Commented out as per flutter/devtools/pull/2001.
//  void _onScrollYChange() {
//    if (controller == null) return;
//
//    // If the vertical position  is already being animated we should not trigger
//    // a new animation of the horizontal position as a more direct animation of
//    // the horizontal position has already been triggered.
//    if (currentAnimateY != null) return;
//
//    final x = _computeTargetX(_scrollControllerY.offset);
//    _scrollControllerX.animateTo(
//      x,
//      duration: defaultDuration,
//      curve: defaultCurve,
//    );
//  }

  /// Compute the goal x scroll given a y scroll value.
  ///
  /// This enables animating the x scroll as the y scroll changes which helps
  /// keep the relevant content in view while scrolling a large list.
  double _computeTargetX(double y) {
    final rowIndex = controller!.getRowIndex(y);
    double? requiredOffset;
    double minOffset = double.infinity;
    // TODO(jacobr): use maxOffset as well to better handle the case where the
    // previous row has a significantly larger indent.

    // TODO(jacobr): if the first or last row is only partially visible, tween
    // between its indent and the next row to more smoothly change the target x
    // as the y coordinate changes.
    if (rowIndex == controller!.numRows) {
      return 0;
    }
    final endY = y += safeViewportHeight;
    for (int i = rowIndex; i < controller!.numRows; i++) {
      final rowY = controller!.getRowY(i);
      if (rowY >= endY) break;

      final row = controller!.getCachedRow(i);
      if (row == null) continue;
      final rowOffset = controller!.getRowOffset(i);
      if (row.isSelected) {
        requiredOffset = rowOffset;
      }
      minOffset = min(minOffset, rowOffset);
    }
    if (requiredOffset == null) {
      return minOffset;
    }

    return minOffset;
  }

  @override
  Future<void> scrollToRect(Rect? rect) async {
    if (rect == _currentAnimateTarget) {
      // We are in the middle of an animation to this exact rectangle.
      return;
    }
    _currentAnimateTarget = rect;
    final targetY = _computeTargetOffsetY(
      rect!.top,
      rect.bottom,
    );
    if (_scrollControllerY.hasClients) {
      _currentAnimateY = _scrollControllerY.animateTo(
        targetY,
        duration: longDuration,
        curve: defaultCurve,
      );
    } else {
      _currentAnimateY = null;
      _scrollControllerY = ScrollController(initialScrollOffset: targetY);
    }

    // Determine a target X coordinate consistent with the target Y coordinate
    // we will end up as so we get a smooth animation to the final destination.
    final targetX = _computeTargetX(targetY);
    if (_scrollControllerX.hasClients) {
      unawaited(_scrollControllerX.animateTo(
        targetX,
        duration: longDuration,
        curve: defaultCurve,
      ));
    } else {
      _scrollControllerX = ScrollController(initialScrollOffset: targetX);
    }

    try {
      await _currentAnimateY;
    } catch (e) {
      // Doesn't matter if the animation was cancelled.
    }
    _currentAnimateY = null;
    _currentAnimateTarget = null;
  }

  // TODO(jacobr): resolve cases where we need to know the viewport height
  // before it is available so we don't need this approximation.
  /// Placeholder viewport height to use if we don't yet know the real
  /// viewport height.
  static const _placeholderViewportHeight = 1000.0;

  double get safeViewportHeight {
    return _scrollControllerY.hasClients
        ? _scrollControllerY.position.viewportDimension
        : _placeholderViewportHeight;
  }

  /// Animate so that the entire range minOffset to maxOffset is within view.
  double _computeTargetOffsetY(
    double minOffset,
    double maxOffset,
  ) {
    final currentOffset = _scrollControllerY.hasClients
        ? _scrollControllerY.offset
        : _scrollControllerY.initialScrollOffset;
    final viewportDimension = safeViewportHeight;
    final currentEndOffset = viewportDimension + currentOffset;

    // If the requested range is larger than what the viewport can show at once,
    // prioritize showing the start of the range.
    maxOffset = min(viewportDimension + minOffset, maxOffset);
    if (currentOffset <= minOffset && currentEndOffset >= maxOffset) {
      return currentOffset; // Nothing to do. The whole range is already in view.
    }
    if (currentOffset > minOffset) {
      // Need to scroll so the minOffset is in view.
      return minOffset;
    }

    assert(currentEndOffset < maxOffset);
    // Need to scroll so the maxOffset is in view at the very bottom of the
    // list view.
    return maxOffset - viewportDimension;
  }

  /// Handle arrow keys for the InspectorTree. Ignore other key events so that
  /// other widgets have a chance to respond to them.
  KeyEventResult _handleKeyEvent(FocusNode _, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      controller!.navigateDown();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      controller!.navigateUp();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      controller!.navigateLeft();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      controller!.navigateRight();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _bindToController() {
    controller?.addClient(this);
  }

  @override
  void onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (controller == null) {
      // Indicate the tree is loading.
      return const CenteredCircularProgressIndicator();
    }
    if (controller!.numRows == 0) {
      // This works around a bug when Scrollbars are present on a short lived
      // widget.
      return const SizedBox();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final Widget tree = Scrollbar(
          thumbVisibility: true,
          controller: _scrollControllerX,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollControllerX,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: controller!.rowWidth + controller!.maxRowIndent!),
              // TODO(kenz): this scrollbar needs to be sticky to the right side of
              // the visible container - right now it is lined up to the right of
              // the widest row (which is likely not visible). This may require some
              // refactoring.
              child: GestureDetector(
                onTap: _focusNode!.requestFocus,
                child: Focus(
                  onKey: _handleKeyEvent,
                  autofocus: widget.isSummaryTree,
                  focusNode: _focusNode,
                  child: OffsetScrollbar(
                    isAlwaysShown: true,
                    axis: Axis.vertical,
                    controller: _scrollControllerY,
                    offsetController: _scrollControllerX,
                    offsetControllerViewportDimension: viewportWidth,
                    child: ListView.custom(
                      itemExtent: rowHeight,
                      childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == controller!.numRows) {
                            return SizedBox(height: rowHeight);
                          }
                          final InspectorTreeRow row =
                              controller!.getCachedRow(index)!;
                          final inspectorRef = row.node.diagnostic?.valueRef.id;
                          return _InspectorTreeRowWidget(
                            key: PageStorageKey(row.node),
                            inspectorTreeState: this,
                            row: row,
                            scrollControllerX: _scrollControllerX,
                            viewportWidth: viewportWidth,
                            error: widget.widgetErrors != null &&
                                    inspectorRef != null
                                ? widget.widgetErrors![inspectorRef]
                                : null,
                            debuggerController: widget.debuggerController,
                          );
                        },
                        childCount: controller!.numRows + 1,
                      ),
                      controller: _scrollControllerY,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final bool shouldShowBreadcrumbs = !widget.isSummaryTree;
        if (shouldShowBreadcrumbs) {
          final parents =
              widget.inspectorTreeController!.getPathFromSelectedRowToRoot();
          return Column(
            children: [
              InspectorBreadcrumbNavigator(
                items: parents,
                onTap: (node) =>
                    widget.inspectorTreeController!.onSelectNode(node),
              ),
              Expanded(child: tree),
            ],
          );
        }

        return tree;
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

Paint _defaultPaint(ColorScheme colorScheme) => Paint()
  ..color = colorScheme.treeGuidelineColor
  ..strokeWidth = chartLineStrokeWidth;

/// Custom painter that draws lines indicating how parent and child rows are
/// connected to each other.
///
/// Each rows object contains a list of ticks that indicate the x coordinates of
/// vertical lines connecting other rows need to be drawn within the vertical
/// area of the current row. This approach has the advantage that a row contains
/// all information required to render all content within it but has the
/// disadvantage that the x coordinates of each line connecting rows must be
/// computed in advance.
class _RowPainter extends CustomPainter {
  _RowPainter(this.row, this._controller, this.colorScheme);

  final InspectorTreeController? _controller;
  final InspectorTreeRow row;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    double currentX = 0;
    final paint = _defaultPaint(colorScheme);

    final InspectorTreeNode node = row.node;
    final bool showExpandCollapse = node.showExpandCollapse;
    for (int tick in row.ticks) {
      currentX = _controller!.getDepthIndent(tick) - columnWidth * 0.5;
      // Draw a vertical line for each tick identifying a connection between
      // an ancestor of this node and some other node in the tree.
      canvas.drawLine(
        Offset(currentX, 0.0),
        Offset(currentX, rowHeight),
        paint,
      );
    }
    // If this row is itself connected to a parent then draw the L shaped line
    // to make that connection.
    if (row.lineToParent) {
      currentX = _controller!.getDepthIndent(row.depth - 1) - columnWidth * 0.5;
      final double width = showExpandCollapse ? columnWidth * 0.5 : columnWidth;
      canvas.drawLine(
        Offset(currentX, 0.0),
        Offset(currentX, rowHeight * 0.5),
        paint,
      );
      canvas.drawLine(
        Offset(currentX, rowHeight * 0.5),
        Offset(currentX + width, rowHeight * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is _RowPainter) {
      // TODO(jacobr): check whether the row has different ticks.
      return oldDelegate.colorScheme.isLight != colorScheme.isLight;
    }
    return true;
  }
}

/// Widget defining the contents of a single row in the InspectorTree.
///
/// This class defines the scaffolding around the rendering of the actual
/// content of a [RemoteDiagnosticsNode] provided by
/// [DiagnosticsNodeDescription] to provide a tree implementation with lines
/// drawn between parent and child nodes when nodes have multiple children.
///
/// Changes to how the actual content of the node within the row should
/// be implemented by changing [DiagnosticsNodeDescription] instead.
class InspectorRowContent extends StatelessWidget {
  const InspectorRowContent({
    required this.row,
    required this.controller,
    required this.onToggle,
    required this.expandArrowAnimation,
    this.error,
    required this.scrollControllerX,
    required this.viewportWidth,
    required this.debuggerController,
  });

  final InspectorTreeRow row;
  final InspectorTreeController? controller;
  final DebuggerController debuggerController;
  final VoidCallback onToggle;
  final Animation<double> expandArrowAnimation;
  final ScrollController? scrollControllerX;
  final double viewportWidth;

  /// A [DevToolsError] that applies to the widget in this row.
  ///
  /// This will be null if there is no error for this row.
  final DevToolsError? error;

  /// Whether this row has any error.
  bool get hasError => error != null;

  @override
  Widget build(BuildContext context) {
    final double currentX = controller!.getDepthIndent(row.depth) - columnWidth;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color? backgroundColor;
    if (row.isSelected) {
      backgroundColor =
          hasError ? devtoolsError : colorScheme.selectedRowBackgroundColor;
    } else if (row.node == controller!.hover) {
      backgroundColor = colorScheme.hoverColor;
    }

    final node = row.node;

    Widget rowWidget = Padding(
      padding: EdgeInsets.only(left: currentX),
      child: ValueListenableBuilder<String>(
        valueListenable: controller!.searchNotifier,
        builder: (context, searchValue, _) {
          return Opacity(
            opacity: searchValue.isEmpty || row.isSearchMatch ? 1 : 0.2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                node.showExpandCollapse
                    ? InkWell(
                        onTap: onToggle,
                        child: RotationTransition(
                          turns: expandArrowAnimation,
                          child: Icon(
                            Icons.expand_more,
                            size: defaultIconSize,
                          ),
                        ),
                      )
                    : const SizedBox(
                        width: defaultSpacing,
                        height: defaultSpacing,
                      ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border:
                          hasError ? Border.all(color: devtoolsError) : null,
                    ),
                    child: InkWell(
                      onTap: () {
                        controller!.onSelectRow(row);
                        // TODO(gmoothart): It may be possible to capture the tap
                        // and request focus directly from the InspectorTree. Then
                        // we wouldn't need this.
                        controller!.requestFocus();
                      },
                      child: Container(
                        height: rowHeight,
                        child: DiagnosticsNodeDescription(
                          node.diagnostic,
                          isSelected: row.isSelected,
                          searchValue: searchValue,
                          errorText: error?.errorMessage,
                          debuggerController: debuggerController,
                          nodeDescriptionHighlightStyle:
                              searchValue.isEmpty || !row.isSearchMatch
                                  ? inspector_text_styles.regular
                                  : row.isSelected
                                      ? theme.searchMatchHighlightStyleFocused
                                      : theme.searchMatchHighlightStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Wrap with tooltip if there is an error for this node's widget.
    if (hasError) {
      rowWidget =
          DevToolsTooltip(child: rowWidget, message: error!.errorMessage);
    }

    return CustomPaint(
      painter: _RowPainter(row, controller, colorScheme),
      size: Size(currentX, rowHeight),
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: scrollControllerX!,
          builder: (context, child) {
            final rowWidth =
                scrollControllerX!.offset + viewportWidth - defaultSpacing;
            return SizedBox(
              width: max(rowWidth, currentX + 100),
              child: rowWidth > currentX ? child : const SizedBox(),
            );
          },
          child: rowWidget,
        ),
      ),
    );
  }
}
