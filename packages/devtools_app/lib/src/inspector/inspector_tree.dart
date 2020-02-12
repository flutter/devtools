// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Inspector specific tree rendering support designed to be extendable to work
/// either directly with dart:html or with Hummingbird.
///
/// This library must not have direct dependencies on dart:html.
///
/// This allows tests of the complicated logic in this class to run on the VM
/// and will help simplify porting this code to work with Hummingbird.
library inspector_tree;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../config_specific/logger/logger.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/icons.dart';
import '../ui/material_icons.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';

/// Split text into two groups, word characters at the start of a string and all
/// other characters.
final RegExp treeNodePrimaryDescriptionPattern = RegExp(r'^([\w ]+)(.*)$');
// TODO(jacobr): temporary workaround for missing structure from assertion thrown building
// widget errors.
final RegExp assertionThrownBuildingError = RegExp(
    r'^(The following assertion was thrown building [a-zA-Z]+)(\(.*\))(:)$');

typedef TreeEventCallback = void Function(InspectorTreeNode node);
typedef TreeHoverEventCallback = void Function(
  InspectorTreeNode node,
  DevToolsIcon icon,
);

const Color selectedRowBackgroundColor = ThemedColor(
  Color.fromARGB(255, 202, 191, 69),
  Color.fromARGB(255, 99, 101, 103),
);
const Color hoverColor = ThemedColor(
  Colors.yellowAccent,
  Color.fromARGB(255, 70, 73, 76),
);
const Color highlightLineColor = ThemedColor(
  Colors.black,
  Color.fromARGB(255, 200, 200, 200),
);

const double iconPadding = 5.0;
const double chartLineStrokeWidth = 1.0;
const double columnWidth = 16.0;
const double verticalPadding = 10.0;
const double rowHeight = 24.0;
const Color arrowColor = Colors.grey;

// TODO(jacobr): these arrows are a bit ugly.
// We should create pngs instead of trying to stretch the material icons into
// being good expand collapse arrows.
final DevToolsIcon collapseArrow = MaterialIcon(
  'arrow_drop_down',
  arrowColor,
  fontSize: 32,
  iconWidth: columnWidth - iconPadding,
  codePoint: Icons.arrow_drop_down.codePoint,
);

final DevToolsIcon expandArrow = MaterialIcon(
  'arrow_drop_down',
  arrowColor,
  fontSize: 32,
  angle: -math.pi / 2, // -90 degrees
  iconWidth: columnWidth - iconPadding,
  codePoint: Icons.arrow_drop_down.codePoint,
);

abstract class PaintEntry {
  PaintEntry();

  DevToolsIcon get icon;

  void attach(InspectorTreeController owner) {}
}

abstract class InspectorTreeNodeRenderBuilder<
    R extends InspectorTreeNodeRender> {
  InspectorTreeNodeRenderBuilder({
    @required this.level,
    @required this.treeStyle,
  });

  void appendText(String text, TextStyle textStyle);

  void addIcon(DevToolsIcon icon);

  final DiagnosticLevel level;
  final DiagnosticsTreeStyle treeStyle;

  InspectorTreeNodeRender build();
}

abstract class InspectorTreeNodeRender<E> {
  InspectorTreeNodeRender(this.entries);

  final List<E> entries;

  PaintEntry hitTest(Offset location);
}

abstract class InspectorTreeNodeRendererLegacy<E extends PaintEntry>
    extends InspectorTreeNodeRender<E> {
  InspectorTreeNodeRendererLegacy(List<E> entries, this.size) : super(entries);

  final Size size;

  void attach(InspectorTreeController owner, Offset offset) {
    if (_owner != owner) {
      _owner = owner;
    }
    _offset = offset;

    for (var entry in entries) {
      entry.attach(owner);
    }
  }

  /// Offset can be updated after the object is created by calling attach
  /// with a new offset.
  Offset get offset => _offset;
  Offset _offset;

  InspectorTreeController _owner;

  Rect get paintBounds => _offset & size;
}

/// This class could be refactored out to be a reasonable generic collapsible
/// tree ui node class but we choose to instead make it widget inspector
/// specific as that is the only case we care about.
// TODO(kenz): extend TreeNode class to share tree logic.
class InspectorTreeNode {
  InspectorTreeNode({
    InspectorTreeNode parent,
    bool expandChildren = true,
  })  : _children = <InspectorTreeNode>[],
        _parent = parent,
        _isExpanded = expandChildren;

  bool get showLinesToChildren {
    return _children.length > 1 && !_children.last.isProperty;
  }

  bool get isDirty => _isDirty;
  bool _isDirty = true;

  set isDirty(bool dirty) {
    if (dirty) {
      _isDirty = true;
      _shouldShow = null;
      if (_childrenCount == null) {
        // Already dirty.
        return;
      }
      _childrenCount = null;
      if (parent != null) {
        parent.isDirty = true;
      }
    } else {
      _isDirty = false;
    }
  }

  /// Returns whether the node is currently visible in the tree.
  void updateShouldShow(bool value) {
    if (value != _shouldShow) {
      _shouldShow = value;
      for (var child in children) {
        child.updateShouldShow(value);
      }
    }
  }

  bool get shouldShow {
    _shouldShow ??= parent == null || parent.isExpanded && parent.shouldShow;
    return _shouldShow;
  }

  bool _shouldShow;

  bool selected = false;

  RemoteDiagnosticsNode _diagnostic;
  final List<InspectorTreeNode> _children;

  Iterable<InspectorTreeNode> get children => _children;

  bool get isCreatedByLocalProject => _diagnostic.isCreatedByLocalProject;

  bool get isProperty => diagnostic == null || diagnostic.isProperty;

  bool get isExpanded => _isExpanded;
  bool _isExpanded;

  bool allowExpandCollapse = true;

  bool get showExpandCollapse {
    return (diagnostic?.hasChildren == true || children.isNotEmpty) &&
        allowExpandCollapse;
  }

  set isExpanded(bool value) {
    if (value != _isExpanded) {
      final bool updateChildren = _shouldShow ?? false;
      _isExpanded = value;
      isDirty = true;
      if (updateChildren) {
        for (var child in children) {
          child.updateShouldShow(value);
        }
      }
    }
  }

  InspectorTreeNode get parent => _parent;
  InspectorTreeNode _parent;

  set parent(InspectorTreeNode value) {
    _parent = value;
    _parent?.isDirty = true;
  }

  RemoteDiagnosticsNode get diagnostic => _diagnostic;

  set diagnostic(RemoteDiagnosticsNode v) {
    _diagnostic = v;
    _isExpanded = v.childrenReady;
    isDirty = true;
  }

  int get childrenCount {
    if (!isExpanded) {
      _childrenCount = 0;
    }
    if (_childrenCount != null) {
      return _childrenCount;
    }
    int count = 0;
    for (InspectorTreeNode child in _children) {
      count += child.subtreeSize;
    }
    _childrenCount = count;
    return _childrenCount;
  }

  bool get hasPlaceholderChildren {
    return children.length == 1 && children.first.diagnostic == null;
  }

  int _childrenCount;

  int get subtreeSize => childrenCount + 1;

  bool get isLeaf => _children.isEmpty;

  // TODO(jacobr): move getRowIndex to the InspectorTree class.
  int getRowIndex(InspectorTreeNode node) {
    int index = 0;
    while (true) {
      final InspectorTreeNode parent = node.parent;
      if (parent == null) {
        break;
      }
      for (InspectorTreeNode sibling in parent._children) {
        if (sibling == node) {
          break;
        }
        index += sibling.subtreeSize;
      }
      index +=
          1; // For parent itself. // TODO(jacobr): need to handle cases where the parent is hidden.
      node = parent;
    }
    return index;
  }

  // TODO(jacobr): move this method to the InspectorTree class.
  // TODO: optimize this method.
  /// Use [getCachedRow] wherever possible, as [getRow] is slow and can cause
  /// performance problems.
  @protected
  InspectorTreeRow getRow(int index) {
    final List<int> ticks = <int>[];
    InspectorTreeNode node = this;
    if (subtreeSize <= index) {
      return null;
    }
    int current = 0;
    int depth = 0;
    while (node != null) {
      final style = node.diagnostic?.style;
      final bool indented = style != DiagnosticsTreeStyle.flat &&
          style != DiagnosticsTreeStyle.error;
      if (current == index) {
        return InspectorTreeRow(
          node: node,
          index: index,
          ticks: ticks,
          depth: depth,
          lineToParent:
              !node.isProperty && index != 0 && node.parent.showLinesToChildren,
        );
      }
      assert(index > current);
      current++;
      final List<InspectorTreeNode> children = node._children;
      int i;
      for (i = 0; i < children.length; ++i) {
        final child = children[i];
        final subtreeSize = child.subtreeSize;
        if (current + subtreeSize > index) {
          node = child;
          if (children.length > 1 &&
              i + 1 != children.length &&
              !children.last.isProperty) {
            if (indented) {
              ticks.add(depth);
            }
          }
          break;
        }
        current += subtreeSize;
      }
      assert(i < children.length);
      if (indented) {
        depth++;
      }
    }
    assert(false); // internal error.
    return null;
  }

  void removeChild(InspectorTreeNode child) {
    child.parent = null;
    final removed = _children.remove(child);
    assert(removed != null);
    isDirty = true;
  }

  void appendChild(InspectorTreeNode child) {
    _children.add(child);
    child.parent = this;
    isDirty = true;
  }

  void clearChildren() {
    _children.clear();
    isDirty = true;
  }
}

/// A row in the tree with all information required to render it.
class InspectorTreeRow {
  const InspectorTreeRow({
    @required this.node,
    @required this.index,
    @required this.ticks,
    @required this.depth,
    @required this.lineToParent,
  });

  final InspectorTreeNode node;

  @override
  bool operator ==(Object other) {
    if (other is InspectorTreeRow) {
      return equalsIgnoringIndex(other) && index == other.index;
    }
    return false;
  }

  bool equalsIgnoringIndex(InspectorTreeRow other) {
    if (other == null) return false;
    return depth == other.depth &&
        depth == other.depth &&
        lineToParent == other.lineToParent &&
        node == other.node;
  }

  @override
  int get hashCode => hashValues(
        depth,
        index,
        lineToParent,
        node,
        ticks.length,
      );

  /// Column indexes of ticks to draw lines from parents to children.
  final List<int> ticks;
  final int depth;
  final int index;
  final bool lineToParent;

  bool get isSelected => node.selected;
}

/// Callback issued every time a node is added to the tree.
typedef NodeAddedCallback = void Function(
    InspectorTreeNode node, RemoteDiagnosticsNode diagnosticsNode);

class InspectorTreeConfig {
  InspectorTreeConfig({
    @required this.summaryTree,
    @required this.treeType,
    @required this.onNodeAdded,
    this.onClientActiveChange,
    this.onSelectionChange,
    this.onExpand,
    this.onHover,
  });

  final bool summaryTree;
  final FlutterTreeType treeType;
  final NodeAddedCallback onNodeAdded;
  final VoidCallback onSelectionChange;
  final void Function(bool added) onClientActiveChange;
  final TreeEventCallback onExpand;
  final TreeHoverEventCallback onHover;
}

class AnimatedRow {
  AnimatedRow({this.last, this.current, this.snapAnimationToEnd = false})
      : animateRow = !_equivalentRows(last, current);

  AnimatedRow.fixed(this.last) : current = last, animateRow = false, snapAnimationToEnd = true;

  final InspectorTreeRow last;
  final InspectorTreeRow current;
  final bool animateRow;
  final bool snapAnimationToEnd;

  InspectorTreeNode get node => targetRow.node;

  InspectorTreeRow get targetRow => current != null ? current : last;

  bool get isSelected => targetRow?.isSelected ?? false;

  static bool _equivalentRows(InspectorTreeRow last, InspectorTreeRow current) {
    if (identical(last, current)) return true;
    if (last == null || current == null) return false;
    return last.equalsIgnoringIndex(current);
  }

  double depth(Animation<double> visibilityAnimation) {
    if (last == null || current == null) {
      return targetRow.depth.toDouble();
    }
    return Tween<double>(
      begin: last.depth.toDouble(),
      end: current.depth.toDouble(),
    ).evaluate(visibilityAnimation);
  }

  double animatedRowHeight(Animation<double> visibilityAnimation) {
    if (!animateRow) {
      return rowHeight;
    }
    if (snapAnimationToEnd && visibilityAnimation.value < 0.999) {
      return beginHeight;
    }
    return Tween<double>(begin: beginHeight, end: endHeight)
        .evaluate(visibilityAnimation);
  }

  double get beginHeight => last != null ? rowHeight : 0;
  double get endHeight => current != null ? rowHeight : 0;
}

abstract class InspectorTreeController {
  // Abstract method defined to avoid a direct Flutter dependency.
  @protected
  void setState(VoidCallback fn);

  InspectorTreeNode get root => _root;
  InspectorTreeNode _root;

  set root(InspectorTreeNode node) {
    setState(() {
      _root = node;
    });
  }

  RemoteDiagnosticsNode subtreeRoot; // Optional.

  InspectorTreeNode get selection => _selection;
  InspectorTreeNode _selection;

  InspectorTreeConfig get config => _config;
  InspectorTreeConfig _config;

  set config(InspectorTreeConfig value) {
    // Only allow setting config once.
    assert(_config == null);
    _config = value;
  }

  set selection(InspectorTreeNode node) {
    if (node == _selection) return;

    setState(() {
      _selection?.selected = false;
      _selection = node;
      _selection?.selected = true;
      if (config.onSelectionChange != null) {
        config.onSelectionChange();
      }
    });
  }

  InspectorTreeNode get hover => _hover;
  InspectorTreeNode _hover;

  double lastContentWidth;

  InspectorTreeNode createNode();

  List<InspectorTreeRow> _cachedRows = [];
  List<InspectorTreeRow> _lastCachedRows = [];

  List<AnimatedRow> _animatedRows = [];

  List<AnimatedRow> get animatedRows {
    _maybeClearCache();
    _updateCache();
    return _animatedRows;
  }

  AnimationController animationController;

  Map<InspectorTreeNode, InspectorTreeRow> _oldRowSet = Map.identity();
  Map<InspectorTreeNode, InspectorTreeRow> _rowSet = Map.identity();

  // TODO: we should add a listener instead that clears the cache when the
  // root is marked as dirty.
  void _maybeClearCache() {
    if (root.isDirty) {
      _lastCachedRows = _cachedRows;
      _cachedRows = [];
      root.isDirty = false;
      _animatedRows = [];
      lastContentWidth = null;
    }
  }

  InspectorTreeRow getCachedRow(int index) {
    _maybeClearCache();
    _updateCache();
    return _cachedRows[index];
  }

  void _updateCache() {
    if (_cachedRows.isEmpty) {
      _oldRowSet = _rowSet;
      _rowSet = Map.identity();
      final numRows = this.numRows;
      // TODO(jacobr): optimize now that we are computing the entire tree anyway.
      for (var i = 0; i < numRows; ++i) {
        final row = root.getRow(i);
        _cachedRows.add(row);
        _rowSet[row.node] = row;
      }
    }
    if (_animatedRows.isEmpty) {
      _animatedRows = [];
      var lastIndex = 0;
      var index = 0;
      while (lastIndex < _lastCachedRows.length || index < _cachedRows.length) {
        final row = _cachedRows.safeGet(index);
        final oldRow = _lastCachedRows.safeGet(lastIndex);
        if (row == null || oldRow == null || row.node == oldRow.node) {
          if (row == oldRow) {
            _animatedRows.add(AnimatedRow(last: oldRow, current: oldRow));
          } else {
            _animatedRows.add(AnimatedRow(last: oldRow, current: row));
          }
          // It is fine that we increment the indexes past the end of the cache
          // for the case where we are out of rows.
          lastIndex++;
          index++;
        } else {
          // We assume there are only additions or subtractions.
          // We would need to do something smarter if there are more complex
          // reorders of combinations of additions and subtractions.
          if (!_rowSet.containsKey(oldRow.node)) {
            _animatedRows.add(AnimatedRow(last: oldRow, current: null));
            lastIndex++;
          } else if (!_oldRowSet.containsKey(row.node)) {
            _animatedRows.add(AnimatedRow(last: null, current: row));
            index++;
          } else {
            // Out of order. We have it a case where the node is in both the old
            // and new trees but we dont know what to do.
            _animatedRows.add(AnimatedRow(last: oldRow, current: row));
            lastIndex++;
            index++;
            assert(false, 'too complex a row animation was requested');
          }
        }
      }
    }
  }

  void optimizeRowAnimation(InspectorTreeNode firstVisible, InspectorTreeNode lastVisible) {
    // Strip out animations at are animating nodes that are not actually in
    // view.
    // TODO(jacobr): consider providing an option to enable animations for nodes
    // slightly outside of view as the difference in handling of outside and
    // inside of view animations could be jarring.
    List<AnimatedRow> simplifiedRows = [];
    if (firstVisible == null) {
      // No rows were visible.
      for (final row in animatedRows) {
        if (row.current != null) {
          simplifiedRows.add(AnimatedRow.fixed(row.current));
        }
      }
    } else {
      int i = 0;
      while (i < animatedRows.length &&
          firstVisible != animatedRows[i].last?.node) {
        final row = animatedRows[i].current;
        if (row != null) {
          simplifiedRows.add(AnimatedRow.fixed(row));
        }
        i++;
      }
      while (i < animatedRows.length) {
        final row = animatedRows[i];
        simplifiedRows.add(row);
        i++;
        if (row.last != null && lastVisible == row.last.node) break;
      }

      while (i < animatedRows.length) {
        final row = animatedRows[i].current;
        if (row != null) {
          simplifiedRows.add(AnimatedRow.fixed(row));
        }
        i++;
      }
    }
    _animatedRows = simplifiedRows;
  }


  AnimatedRow getAnimatedRow(int index) {
    _maybeClearCache();
    _updateCache();
    return _animatedRows.safeGet(index);
  }

  int get animatedRowsLength => _animatedRows.length;

  void animationDone() {
    _lastCachedRows = _cachedRows;
    _maybeClearCache();
    _updateCache();
    _animatedRows = [for (var row in _cachedRows) AnimatedRow.fixed(row)];
  }

  double getRowOffset(int index) {
    return (getCachedRow(index)?.depth ?? 0) * columnWidth;
  }

  set hover(InspectorTreeNode node) {
    if (node == _hover) {
      return;
    }
    setState(() {
      _hover = node;
      // TODO(jacobr): we could choose to repaint only a portion of the UI
    });
  }

  RemoteDiagnosticsNode currentHoverDiagnostic;

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

    if (selection.isExpanded) {
      setState(() {
        selection.isExpanded = false;
      });
      return;
    }
    if (selection.parent != null) {
      selection = selection.parent;
    }
  }

  void navigateRight() {
    // This logic is consistent with how IntelliJ handles tree navigation on
    // on right arrow key press.

    if (selection == null || selection.isExpanded) {
      _navigateHelper(1);
      return;
    }

    setState(() {
      selection.isExpanded = true;
    });
  }

  void _navigateHelper(int indexOffset) {
    if (numRows == 0) return;

    if (selection == null) {
      selection = root;
      return;
    }

    selection = root
        .getRow(
            (root.getRowIndex(selection) + indexOffset).clamp(0, numRows - 1))
        ?.node;
  }

  double get horizontalPadding => 10.0;

  double getDepthIndent(num depth) {
    return (depth.toDouble() + 1) * columnWidth + horizontalPadding;
  }

  double getRowY(int index) {
    return rowHeight * index + verticalPadding;
  }

  void nodeChanged(InspectorTreeNode node) {
    if (node == null) return;
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

  void expandPath(InspectorTreeNode node) {
    setState(() {
      _expandPath(node);
    });
  }

  void _expandPath(InspectorTreeNode node) {
    while (node != null) {
      if (!node.isExpanded) {
        node.isExpanded = true;
      }
      node = node.parent;
    }
  }

  void collapseToSelected() {
    setState(() {
      _collapseAllNodes(root);
      if (selection == null) return;
      _expandPath(selection);
    });
  }

  void _collapseAllNodes(InspectorTreeNode root) {
    root.isExpanded = false;
    root.children.forEach(_collapseAllNodes);
  }

  int get numRows => root != null ? root.subtreeSize : 0;

  int getRowIndex(double y) => (y - verticalPadding) ~/ rowHeight;

  InspectorTreeRow getRowForNode(InspectorTreeNode node) {
    _maybeClearCache();
    _updateCache();
    if (!_rowSet.containsKey(node)) return null;
    return getCachedRow(root.getRowIndex(node));
  }

  InspectorTreeRow getRow(Offset offset) {
    if (root == null) return null;
    final int row = getRowIndex(offset.dy);
    return row < root.subtreeSize ? getCachedRow(row) : null;
  }

  void animateToTargets(List<InspectorTreeNode> targets);

  void onExpandRow(InspectorTreeRow row) {
    setState(() {
      row.node.isExpanded = true;
      if (config.onExpand != null) {
        config.onExpand(row.node);
      }
    });
  }

  void onCollapseRow(InspectorTreeRow row) {
    setState(() {
      row.node.isExpanded = false;
    });
  }

  void onSelectRow(InspectorTreeRow row) {
    selection = row.node;
    expandPath(row.node);
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
    return true;
  }

  InspectorTreeNode setupInspectorTreeNode(
    InspectorTreeNode node,
    RemoteDiagnosticsNode diagnosticsNode, {
    @required bool expandChildren,
    @required bool expandProperties,
  }) {
    assert(expandChildren != null);
    assert(expandProperties != null);
    node.diagnostic = diagnosticsNode;
    if (config.onNodeAdded != null) {
      config.onNodeAdded(node, diagnosticsNode);
    }

    if (diagnosticsNode.hasChildren ||
        diagnosticsNode.inlineProperties.isNotEmpty) {
      if (diagnosticsNode.childrenReady || !diagnosticsNode.hasChildren) {
        final bool styleIsMultiline =
            expandPropertiesByDefault(diagnosticsNode.style);
        setupChildren(
          diagnosticsNode,
          node,
          node.diagnostic.childrenNow,
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
    List<RemoteDiagnosticsNode> children, {
    @required bool expandChildren,
    @required bool expandProperties,
  }) {
    assert(expandChildren != null);
    assert(expandProperties != null);
    treeNode.isExpanded = expandChildren;
    if (treeNode.children.isNotEmpty) {
      // Only case supported is this is the loading node.
      assert(treeNode.children.length == 1);
      removeNodeFromParent(treeNode.children.first);
    }
    final inlineProperties = parent.inlineProperties;

    if (inlineProperties != null) {
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
    final RemoteDiagnosticsNode diagnostic = treeNode.diagnostic;
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
}

mixin InspectorTreeFixedRowHeightController on InspectorTreeController {
  Rect getBoundingBox(InspectorTreeRow row);

  void scrollToRect(Rect targetRect);

  @override
  void animateToTargets(List<InspectorTreeNode> targets) {
    Rect targetRect;

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
}
