// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/analytics/metrics.dart';
import '../../shared/collapsible_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/console/eval/inspector_tree_v2.dart';
import '../../shared/console/widgets/description.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/diagnostics_text_styles.dart';
import '../../shared/error_badge_manager.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/utils.dart';
import '../../shared/utils.dart';
import 'inspector_breadcrumbs.dart';
import 'inspector_controller.dart';

final _log = Logger('inspector_tree_controller');

/// Presents a [TreeNode].
class _InspectorTreeRowWidget extends StatefulWidget {
  /// Constructs a [_InspectorTreeRowWidget] that presents a line in the
  /// Inspector tree.
  const _InspectorTreeRowWidget({
    required super.key,
    required this.row,
    required this.inspectorTreeState,
    this.error,
    required this.scrollControllerX,
    required this.viewportWidth,
  });

  final _InspectorTreeState inspectorTreeState;

  InspectorTreeNode get node => row.node;
  final InspectorTreeRow row;
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
      height: inspectorRowHeight,
      child: InspectorRowContent(
        row: widget.row,
        error: widget.error,
        expandArrowAnimation: expandArrowAnimation,
        controller: widget.inspectorTreeState.treeController!,
        scrollControllerX: widget.scrollControllerX,
        viewportWidth: widget.viewportWidth,
        onToggle: () {
          setExpanded(!isExpanded);
        },
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
        widget.inspectorTreeState.treeController!.onExpandRow(row);
      } else {
        widget.inspectorTreeState.treeController!.onCollapseRow(row);
      }
    });
  }

  @override
  bool shouldShow() => widget.node.shouldShow;
}

class InspectorTreeController extends DisposableController
    with SearchControllerMixin<InspectorTreeRow> {
  InspectorTreeController({this.gaId}) {
    ga.select(
      gac.inspector,
      gac.inspectorTreeControllerInitialized,
      nonInteraction: true,
      screenMetricsProvider: () => InspectorScreenMetrics.v2(
        inspectorTreeControllerId: gaId,
        rootSetCount: _rootSetCount,
        rowCount: _cachedRows.length,
      ),
    );
  }

  /// Clients the controller notifies to trigger changes to the UI.
  final _clients = <InspectorControllerClient>{};

  /// Identifier used when sending Google Analytics about events in this
  /// [InspectorTreeController].
  final int? gaId;

  InspectorTreeNode createNode() => InspectorTreeNode();

  SearchTargetType _searchTarget = SearchTargetType.widget;
  int _rootSetCount = 0;

  void addClient(InspectorControllerClient value) {
    final firstClient = _clients.isEmpty;
    _clients.add(value);
    if (firstClient) {
      config.onClientActiveChange?.call(true);
    }
  }

  void removeClient(InspectorControllerClient value) {
    _clients.remove(value);
    if (_clients.isEmpty) {
      config.onClientActiveChange?.call(false);
    }
  }

  // Method defined to avoid a direct Flutter dependency.
  void setState(VoidCallback fn) {
    fn();
    for (final client in _clients) {
      client.onChanged();
    }
  }

  void requestFocus() {
    for (final client in _clients) {
      client.requestFocus();
    }
  }

  InspectorTreeNode? get root => _root;
  InspectorTreeNode? _root;

  set root(InspectorTreeNode? node) {
    setState(() {
      if (node != null) {
        final rows = node.buildRows();
        _cachedRows.clear();
        _cachedRows.addAll(rows);
        // When root is set, all nodes are expanded so these are the same:
        _searchableCachedRows.clear();
        _searchableCachedRows.addAll(rows);
      }
      _root = node;

      ga.select(
        gac.inspector,
        gac.inspectorTreeControllerRootChange,
        nonInteraction: true,
        screenMetricsProvider: () => InspectorScreenMetrics.v2(
          inspectorTreeControllerId: gaId,
          rootSetCount: ++_rootSetCount,
          rowCount: _cachedRows.length,
        ),
      );
    });
  }

  InspectorTreeNode? get selection => _selection;
  InspectorTreeNode? _selection;

  late final InspectorTreeConfig config;

  set selection(InspectorTreeNode? node) {
    if (node == _selection) return;

    setState(() {
      _selection?.selected = false;
      _selection = node;
      _selection?.selected = true;
      final configLocal = config;
      if (configLocal.onSelectionChange != null) {
        configLocal.onSelectionChange!();
      }
    });
  }

  InspectorTreeNode? get hover => _hover;
  InspectorTreeNode? _hover;

  double? lastContentWidth;

  InspectorTreeRow? _cachedSelectedRow;

  /// All cached rows of the tree.
  ///
  /// Similar to [cachedRows] but:
  /// * contains every row in the tree (including collapsed rows)
  /// * items don't change when nodes are expanded or collapsed
  /// * items are populated only when root is changed
  final _searchableCachedRows = <InspectorTreeRow?>[];

  final _cachedRows = <InspectorTreeRow?>[];

  void setSearchTarget(SearchTargetType searchTarget) {
    _searchTarget = searchTarget;
    refreshSearchMatches();
  }

  // TODO: we should add a listener instead that clears the cache when the
  // root is marked as dirty.
  void _maybeClearCache() {
    final rootLocal = root;
    if (rootLocal != null && rootLocal.isDirty) {
      _cachedSelectedRow = null;
      rootLocal.isDirty = false;
      lastContentWidth = null;
      _refreshCache();
    }
  }

  void _refreshCache() {
    if (root != null) {
      final rows = root!.buildRows();
      _cachedRows.clear();
      _cachedRows.addAll(rows);
    }
  }

  InspectorTreeRow? getCachedRow(int index) {
    if (index < 0) return null;

    _maybeClearCache();
    if (_cachedRows.length > index) {
      return _cachedRows[index];
    }
    return null;
  }

  double getRowOffset(int index) {
    return (getCachedRow(index)?.depth ?? 0) * inspectorColumnIndent;
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
    final selectionLocal = selection;

    // This logic is consistent with how IntelliJ handles tree navigation on
    // on left arrow key press.
    if (selectionLocal == null) {
      _navigateHelper(-1);
      return;
    }

    if (selectionLocal.isExpanded) {
      setState(() {
        selectionLocal.isExpanded = false;
      });
      return;
    }
    if (selectionLocal.parent != null) {
      selection = selectionLocal.parent;
    }
  }

  int getRowIndex(node) {
    for (int i = 0; i <= _cachedRows.length; i++) {
      if (_cachedRows[i]?.node == node) {
        return i;
      }
    }
    return -1;
  }

  void navigateRight() {
    // This logic is consistent with how IntelliJ handles tree navigation on
    // on right arrow key press.

    final selectionLocal = selection;

    if (selectionLocal == null || selectionLocal.isExpanded) {
      _navigateHelper(1);
      return;
    }

    setState(() {
      selectionLocal.isExpanded = true;
    });
  }

  void _navigateHelper(int indexOffset) {
    if (numRows == 0) return;

    if (selection == null) {
      selection = root;
      return;
    }

    selection = getCachedRow(
      (getRowIndex(selection!) + indexOffset)
              .clamp(0, numRows - 1),
        )
        ?.node;
  }

  double get horizontalPadding => 10.0;

  /// Returns the indentation of a row at the given [depth] in the inspector.
  ///
  /// This indentation roughly corresponds to the center of the icon next to the
  /// widget name.
  double getDepthIndent(int depth) {
    // Note: depth is 0-based, therefore add 1.
    return (depth + 1) * inspectorColumnIndent + horizontalPadding;
  }

  double rowYTop(int index) {
    return inspectorRowHeight * index;
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

  int get numRows => _cachedRows.length;

  InspectorTreeRow? getRowForNode(InspectorTreeNode node) {
    final rootLocal = root;
    if (rootLocal == null) return null;
    return getCachedRow(getRowIndex(node));
  }

  InspectorTreeRow? getRow(Offset offset) {
    final rootLocal = root;
    if (rootLocal == null) return null;
    final row = getRowIndex(offset.dy);
    return row < _cachedRows.length ? getCachedRow(row) : null;
  }

  void onExpandRow(InspectorTreeRow row) {
    setState(() {
      final onExpand = config.onExpand;
      row.node.isExpanded = true;
      if (onExpand != null) {
        onExpand(row.node);
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
      gac.inspector,
      gac.treeNodeSelection,
    );
    expandPath(node);
  }

  Rect getBoundingBox(InspectorTreeRow row) {
    // For future reference: the bounding box likely needs to be in terms of
    // positions after the current animations are complete so that computations
    // to start animations to show specific widget scroll to where the target
    // nodes will be displayed rather than where they are currently displayed.
    final diagnostic = row.node.diagnostic;
    // The node width is approximated since the widgets are not available at the
    // time of calculating the bounding box.
    final approximateNodeWidth =
        DiagnosticsNodeDescription.approximateNodeWidth(diagnostic);
    return Rect.fromLTWH(
      getDepthIndent(row.depth),
      rowYTop(row.index),
      approximateNodeWidth,
      inspectorRowHeight,
    );
  }

  void scrollToRect(Rect targetRect) {
    for (final client in _clients) {
      client.scrollToRect(targetRect);
    }
  }

  /// Width each row in the tree should have ignoring its indent.
  ///
  /// Content in rows should wrap if it exceeds this width.
  final rowWidth = 1200;

  /// Maximum indent of the tree in pixels.
  double? _maxIndent;

  double get maxRowIndent {
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
    return _maxIndent!;
  }

  void animateToTargets(List<InspectorTreeNode> targets) {
    Rect? targetRect;

    for (final target in targets) {
      final row = getRowForNode(target);
      if (row != null) {
        final rowRect = getBoundingBox(row);
        targetRect =
            targetRect == null ? rowRect : targetRect.expandToInclude(rowRect);
      }
    }

    if (targetRect == null || targetRect.isEmpty) return;

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
    final configLocal = config;
    if (configLocal.onNodeAdded != null) {
      configLocal.onNodeAdded!(node, diagnosticsNode);
    }

    if (diagnosticsNode.hasChildren ||
        diagnosticsNode.inlineProperties.isNotEmpty) {
      if (diagnosticsNode.childrenReady || !diagnosticsNode.hasChildren) {
        final styleIsMultiline =
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

    for (final property in inlineProperties) {
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
      for (final child in children) {
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
    final diagnostic = treeNode.diagnostic;
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
      } catch (e, st) {
        _log.shout(e, e, st);
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

  @override
  List<InspectorTreeRow> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    final matches = <InspectorTreeRow>[];

    if (searchPreviousMatches) {
      final previousMatches = searchMatches.value;
      for (final previousMatch in previousMatches) {
        if (previousMatch.node.diagnostic!.searchValue
            .caseInsensitiveContains(search)) {
          matches.add(previousMatch);
        }
      }

      if (matches.isNotEmpty) return matches;
    }

    int debugStatsSearchOps = 0;
    final debugStatsWidgets = _searchableCachedRows.length;

    final inspectorService = serviceConnection.inspectorService;
    if (search.isEmpty ||
        inspectorService == null ||
        inspectorService.isDisposed) {
      assert(
        () {
          debugPrint('Search completed, no search');
          return true;
        }(),
      );
      return matches;
    }

    assert(
      () {
        debugPrint('Search started: $_searchTarget');
        return true;
      }(),
    );

    for (final row in _searchableCachedRows) {
      final diagnostic = row!.node.diagnostic;
      if (diagnostic == null) continue;

      // Widget search begin
      if (_searchTarget == SearchTargetType.widget) {
        debugStatsSearchOps++;
        if (diagnostic.searchValue.caseInsensitiveContains(search)) {
          matches.add(row);
          continue;
        }
      }
      // Widget search end
    }

    assert(
      () {
        debugPrint(
          'Search completed with $debugStatsWidgets widgets, $debugStatsSearchOps ops',
        );
        return true;
      }(),
    );

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

  void scrollToRect(Rect rect);

  void requestFocus();
}

class InspectorTree extends StatefulWidget {
  const InspectorTree({
    super.key,
    required this.treeController,
    this.summaryTreeController,
    this.isSummaryTree = false,
    this.widgetErrors,
    this.screenId,
  }) : assert(isSummaryTree == (summaryTreeController == null));

  final InspectorTreeController? treeController;

  /// Stores the summary tree controller when this instance of [InspectorTree]
  /// is for the details tree (i.e. when [isSummaryTree] is false).
  ///
  /// This value should be null when this instance of [InspectorTree] is for the
  /// summary tree itself.
  final InspectorTreeController? summaryTreeController;

  final bool isSummaryTree;
  final LinkedHashMap<String, InspectableWidgetError>? widgetErrors;
  final String? screenId;

  @override
  State<InspectorTree> createState() => _InspectorTreeState();
}

// AutomaticKeepAlive is necessary so that the tree does not get recreated when we switch tabs.
class _InspectorTreeState extends State<InspectorTree>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<InspectorTree>,
        AutoDisposeMixin,
        ProvidedControllerMixin<InspectorController, InspectorTree>
    implements InspectorControllerClient {
  InspectorTreeController? get treeController => widget.treeController;

  late ScrollController _scrollControllerY;
  late ScrollController _scrollControllerX;
  Future<void>? _currentAnimateY;
  Rect? _currentAnimateTarget;

  AnimationController? _constraintDisplayController;
  late FocusNode _focusNode;

  /// When autoscrolling, the number of rows to pad the target location with.
  static const _scrollPadCount = 3;

  @override
  void initState() {
    super.initState();
    _scrollControllerX = ScrollController();
    _scrollControllerY = ScrollController();
    // TODO(devoncarew): Commented out as per flutter/devtools/pull/2001.
    //_scrollControllerY.addListener(_onScrollYChange);
    if (widget.isSummaryTree) {
      _constraintDisplayController = longAnimationController(this);
    }
    _focusNode = FocusNode(debugLabel: 'inspector-tree');
    autoDisposeFocusNode(_focusNode);
    final mainIsolateState =
        serviceConnection.serviceManager.isolateManager.mainIsolateState;
    if (mainIsolateState != null) {
      callOnceWhenReady<bool>(
        trigger: mainIsolateState.isPaused,
        callback: _bindToController,
        readyWhen: (triggerValue) => !triggerValue,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
  }

  @override
  void didUpdateWidget(InspectorTree oldWidget) {
    final oldTreeController = oldWidget.treeController;
    if (oldTreeController != widget.treeController) {
      oldTreeController?.removeClient(this);

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
    treeController?.removeClient(this);
    _scrollControllerX.dispose();
    _scrollControllerY.dispose();
    _constraintDisplayController?.dispose();
  }

  @override
  void requestFocus() {
    _focusNode.requestFocus();
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

  @override
  Future<void> scrollToRect(Rect rect) async {
    if (rect == _currentAnimateTarget) {
      // We are in the middle of an animation to this exact rectangle.
      return;
    }

    final initialX = rect.left;
    final initialY = rect.top;
    final yOffsetAtViewportTop = _scrollControllerY.hasClients
        ? _scrollControllerY.offset
        : _scrollControllerY.initialScrollOffset;
    final xOffsetAtViewportLeft = _scrollControllerX.hasClients
        ? _scrollControllerX.offset
        : _scrollControllerX.initialScrollOffset;

    final viewPortInScrollControllerSpace = Rect.fromLTWH(
      xOffsetAtViewportLeft,
      yOffsetAtViewportTop,
      safeViewportWidth,
      safeViewportHeight,
    );

    final isRectInViewPort =
        viewPortInScrollControllerSpace.contains(rect.topLeft) &&
            viewPortInScrollControllerSpace.contains(rect.bottomRight);
    if (isRectInViewPort) {
      // The rect is already in view, don't scroll
      return;
    }

    _currentAnimateTarget = rect;

    final targetY = _padTargetY(initialY: initialY);
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

    final targetX = _padTargetX(initialX: initialX);
    if (_scrollControllerX.hasClients) {
      unawaited(
        _scrollControllerX.animateTo(
          targetX,
          duration: longDuration,
          curve: defaultCurve,
        ),
      );
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
  static const _placeholderViewportSize = Size(1000.0, 1000.0);

  double get safeViewportHeight {
    return _scrollControllerY.hasClients
        ? _scrollControllerY.position.viewportDimension
        : _placeholderViewportSize.height;
  }

  double get safeViewportWidth {
    return _scrollControllerX.hasClients
        ? _scrollControllerX.position.viewportDimension
        : _placeholderViewportSize.width;
  }

  /// Pad [initialX] with the horizontal indentation of [padCount] rows.
  double _padTargetX({
    required double initialX,
    int padCount = _scrollPadCount,
  }) {
    return initialX - inspectorColumnIndent * padCount;
  }

  /// Pad [initialY] so that a row would be placed in the vertical center of
  /// the screen.
  double _padTargetY({
    required double initialY,
  }) {
    return initialY - (safeViewportHeight / 2) + inspectorRowHeight / 2;
  }

  /// Handle arrow keys for the InspectorTree. Ignore other key events so that
  /// other widgets have a chance to respond to them.
  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (!event.isKeyDownOrRepeat) return KeyEventResult.ignored;

    final treeControllerLocal = treeController!;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      treeControllerLocal.navigateDown();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      treeControllerLocal.navigateUp();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      treeControllerLocal.navigateLeft();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      treeControllerLocal.navigateRight();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _bindToController() {
    treeController?.addClient(this);
  }

  @override
  void onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final treeControllerLocal = treeController;
    if (treeControllerLocal == null) {
      // Indicate the tree is loading.
      return const CenteredCircularProgressIndicator();
    }
    if (treeControllerLocal.numRows == 0) {
      // This works around a bug when Scrollbars are present on a short lived
      // widget.
      return const SizedBox();
    }

    if (!controller.firstInspectorTreeLoadCompleted && widget.isSummaryTree) {
      final screenId = widget.screenId;
      if (screenId != null) {
        ga.timeEnd(screenId, gac.pageReady);
        unawaited(
          serviceConnection.sendDwdsEvent(
            screen: screenId,
            action: gac.pageReady,
          ),
        );
      }
      controller.firstInspectorTreeLoadCompleted = true;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final tree = Scrollbar(
          thumbVisibility: true,
          controller: _scrollControllerX,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollControllerX,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: treeControllerLocal.rowWidth +
                    treeControllerLocal.maxRowIndent,
              ),
              // TODO(kenz): this scrollbar needs to be sticky to the right side of
              // the visible container - right now it is lined up to the right of
              // the widest row (which is likely not visible). This may require some
              // refactoring.
              child: GestureDetector(
                onTap: _focusNode.requestFocus,
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  autofocus: widget.isSummaryTree,
                  focusNode: _focusNode,
                  child: OffsetScrollbar(
                    isAlwaysShown: true,
                    axis: Axis.vertical,
                    controller: _scrollControllerY,
                    offsetController: _scrollControllerX,
                    offsetControllerViewportDimension: viewportWidth,
                    child: ListView.custom(
                      itemExtent: inspectorRowHeight,
                      childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == treeControllerLocal.numRows) {
                            return SizedBox(height: inspectorRowHeight);
                          }
                          final row = treeControllerLocal.getCachedRow(index)!;
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
                          );
                        },
                        childCount: treeControllerLocal.numRows + 1,
                      ),
                      controller: _scrollControllerY,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final shouldShowBreadcrumbs = !widget.isSummaryTree;
        if (shouldShowBreadcrumbs) {
          final inspectorTreeController = widget.summaryTreeController!;

          final parents =
              inspectorTreeController.getPathFromSelectedRowToRoot();
          return Column(
            children: [
              InspectorBreadcrumbNavigator(
                items: parents,
                onTap: (node) => inspectorTreeController.onSelectNode(node),
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

/// The distance (on the x-axis) between the expand/collapse and the start of
/// the row, as determined by a percentage of the [inspectorColumnIndent].
const _expandCollapseToRowStartXDistancePercentage = 0.68;

/// The distance (on the x-axis) between the center of the widget icon and the
/// start of the row, as determined by a percentage of the
/// [inspectorColumnIndent].
const _iconCenterToRowStartXDistancePercentage = 0.15;

/// The distance (on the y-axis) between the bottom of the widget icon and the
/// top of the row, as determined by a percentage of the [inspectorRowHeight].
const _iconBottomToRowTopYDistancePercentage = 0.75;

/// The distance (on the y-axis) between the top of the child widget's icon and
/// the top of the current row, as determined by a percentage of the
/// [inspectorRowHeight].
const _childIconTopToRowTopYDistancePercentage = 1.25;

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

  final InspectorTreeController _controller;
  final InspectorTreeRow row;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _defaultPaint(colorScheme);

    final node = row.node;
    final showExpandCollapse = node.showExpandCollapse;
    final distanceFromExpandCollapseToRowStart =
        inspectorColumnIndent * _expandCollapseToRowStartXDistancePercentage;
    for (final tick in row.ticks) {
      final expandCollapseX = _controller.getDepthIndent(tick) -
          distanceFromExpandCollapseToRowStart;
      // Draw a vertical line for each tick identifying a connection between
      // an ancestor of this node and some other node in the tree.
      canvas.drawLine(
        Offset(expandCollapseX, 0.0),
        Offset(expandCollapseX, inspectorRowHeight),
        paint,
      );
    }
    // If this row is itself connected to a parent then draw the L shaped line
    // to make that connection.
    if (row.lineToParent) {
      final parentExpandCollapseX = _controller.getDepthIndent(row.depth - 1) -
          distanceFromExpandCollapseToRowStart;
      final width = showExpandCollapse
          ? inspectorColumnIndent * 0.6
          : inspectorColumnIndent;
      canvas.drawLine(
        Offset(parentExpandCollapseX, 0.0),
        Offset(parentExpandCollapseX, inspectorRowHeight * 0.5),
        paint,
      );
      canvas.drawLine(
        Offset(parentExpandCollapseX, inspectorRowHeight * 0.5),
        Offset(parentExpandCollapseX + width, inspectorRowHeight * 0.5),
        paint,
      );
    }

    if (row.hasSingleChild && node.isExpanded) {
      final distanceFromIconCenterToRowStart =
          inspectorColumnIndent * _iconCenterToRowStartXDistancePercentage;
      final iconCenterX = _controller.getDepthIndent(row.depth) -
          distanceFromIconCenterToRowStart;
      // Draw a line from the bottom of the current row's icon to the top of the
      // child row's icon:
      canvas.drawLine(
        Offset(
          iconCenterX,
          inspectorRowHeight * _iconBottomToRowTopYDistancePercentage,
        ),
        Offset(
          iconCenterX,
          inspectorRowHeight * _childIconTopToRowTopYDistancePercentage,
        ),
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
    super.key,
    required this.row,
    required this.controller,
    required this.onToggle,
    required this.expandArrowAnimation,
    this.error,
    required this.scrollControllerX,
    required this.viewportWidth,
  });

  final InspectorTreeRow row;
  final InspectorTreeController controller;
  final VoidCallback onToggle;
  final Animation<double> expandArrowAnimation;
  final ScrollController scrollControllerX;
  final double viewportWidth;

  /// A [DevToolsError] that applies to the widget in this row.
  ///
  /// This will be null if there is no error for this row.
  final DevToolsError? error;

  /// Whether this row has any error.
  bool get hasError => error != null;

  @override
  Widget build(BuildContext context) {
    final currentX =
        controller.getDepthIndent(row.depth) - inspectorColumnIndent;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color? backgroundColor;
    if (row.isSelected) {
      backgroundColor = hasError
          ? colorScheme.errorContainer
          : colorScheme.selectedRowBackgroundColor;
    }

    final node = row.node;

    Widget rowWidget = Padding(
      padding: EdgeInsets.only(left: currentX),
      child: ValueListenableBuilder<String>(
        valueListenable: controller.searchNotifier,
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
                  child: Container(
                    color: backgroundColor,
                    child: InkWell(
                      onTap: () {
                        controller.onSelectRow(row);
                        // TODO(gmoothart): It may be possible to capture the tap
                        // and request focus directly from the InspectorTree. Then
                        // we wouldn't need this.
                        controller.requestFocus();
                      },
                      child: SizedBox(
                        height: inspectorRowHeight,
                        child: DiagnosticsNodeDescription(
                          node.diagnostic,
                          isSelected: row.isSelected,
                          searchValue: searchValue,
                          errorText: error?.errorMessage,
                          emphasizeNodesFromLocalProject: true,
                          nodeDescriptionHighlightStyle:
                              searchValue.isEmpty || !row.isSearchMatch
                                  ? DiagnosticsTextStyles.regular(
                                      Theme.of(context).colorScheme,
                                    )
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
          DevToolsTooltip(message: error!.errorMessage, child: rowWidget);
    }

    return CustomPaint(
      painter: _RowPainter(row, controller, colorScheme),
      size: Size(currentX, inspectorRowHeight),
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: scrollControllerX,
          builder: (context, child) {
            final rowWidth =
                scrollControllerX.offset + viewportWidth - defaultSpacing;
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
