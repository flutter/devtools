// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Inspector specific tree rendering support.
///
/// This library must not have direct dependencies on web-only libraries.
///
/// This allows tests of the complicated logic in this class to run on the VM.
library;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';

import '../../diagnostics/diagnostics_node.dart';
import '../../ui/search.dart';

/// Split text into two groups, word characters at the start of a string and all
/// other characters.
final RegExp treeNodePrimaryDescriptionPattern = RegExp(r'^([\w ]+)(.*)$');
// TODO(jacobr): temporary workaround for missing structure from assertion thrown building
// widget errors.
final RegExp assertionThrownBuildingError = RegExp(
  r'^(The following assertion was thrown building [a-zA-Z]+)(\(.*\))(:)$',
);

typedef TreeEventCallback = void Function(InspectorTreeNode node);

const double iconPadding = 4.0;
const double chartLineStrokeWidth = 1.0;
double get columnWidth => scaleByFontFactor(12.0);
double get rowHeight => scaleByFontFactor(16.0);

/// This class could be refactored out to be a reasonable generic collapsible
/// tree ui node class but we choose to instead make it widget inspector
/// specific as that is the only case we care about.
// TODO(kenz): extend TreeNode class to share tree logic.
class InspectorTreeNode {
  InspectorTreeNode({
    InspectorTreeNode? parent,
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
        parent!.isDirty = true;
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
    final parentLocal = parent;
    _shouldShow ??=
        parentLocal == null || parentLocal.isExpanded && parentLocal.shouldShow;
    return _shouldShow!;
  }

  bool? _shouldShow;

  bool selected = false;

  RemoteDiagnosticsNode? _diagnostic;
  final List<InspectorTreeNode> _children;

  Iterable<InspectorTreeNode> get children => _children;

  bool get isProperty {
    final diagnosticLocal = diagnostic;
    return diagnosticLocal == null || diagnosticLocal.isProperty;
  }

  bool get isExpanded => _isExpanded;
  bool _isExpanded;

  bool allowExpandCollapse = true;

  bool get showExpandCollapse {
    return (diagnostic?.hasChildren == true || children.isNotEmpty) &&
        allowExpandCollapse;
  }

  set isExpanded(bool value) {
    if (value != _isExpanded) {
      _isExpanded = value;
      isDirty = true;
      if (_shouldShow ?? false) {
        for (var child in children) {
          child.updateShouldShow(value);
        }
      }
    }
  }

  InspectorTreeNode? get parent => _parent;
  InspectorTreeNode? _parent;

  set parent(InspectorTreeNode? value) {
    _parent = value;
    _parent?.isDirty = true;
  }

  RemoteDiagnosticsNode? get diagnostic => _diagnostic;

  set diagnostic(RemoteDiagnosticsNode? v) {
    final value = v!;
    _diagnostic = value;
    _isExpanded = value.childrenReady;
    isDirty = true;
  }

  int get childrenCount {
    if (!isExpanded) {
      _childrenCount = 0;
    }
    final childrenCountLocal = _childrenCount;
    if (childrenCountLocal != null) {
      return childrenCountLocal;
    }
    int count = 0;
    for (InspectorTreeNode child in _children) {
      count += child.subtreeSize;
    }
    return _childrenCount = count;
  }

  bool get hasPlaceholderChildren {
    return children.length == 1 && children.first.diagnostic == null;
  }

  int? _childrenCount;

  int get subtreeSize => childrenCount + 1;

  // TODO(jacobr): move getRowIndex to the InspectorTree class.
  int getRowIndex(InspectorTreeNode node) {
    int index = 0;
    while (true) {
      final InspectorTreeNode? parent = node.parent;
      if (parent == null) {
        break;
      }
      for (InspectorTreeNode sibling in parent._children) {
        if (sibling == node) {
          break;
        }
        index += sibling.subtreeSize;
      }
      index += 1; // For parent itself.
      node = parent;
    }
    return index;
  }

  // TODO(jacobr): move this method to the InspectorTree class.
  // TODO: optimize this method.
  /// Use [getCachedRow] wherever possible, as [getRow] is slow and can cause
  /// performance problems.
  InspectorTreeRow? getRow(int index) {
    if (subtreeSize <= index) {
      return null;
    }

    final List<int> ticks = <int>[];
    InspectorTreeNode node = this;
    int current = 0;
    int depth = 0;

    // Iterate till getting the result to return.
    while (true) {
      final style = node.diagnostic?.style;
      final bool indented = style != DiagnosticsTreeStyle.flat &&
          style != DiagnosticsTreeStyle.error;
      if (current == index) {
        return InspectorTreeRow(
          node: node,
          index: index,
          ticks: ticks,
          depth: depth,
          lineToParent: !node.isProperty &&
              index != 0 &&
              node.parent!.showLinesToChildren,
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
  }

  void removeChild(InspectorTreeNode child) {
    child.parent = null;
    final removed = _children.remove(child);
    assert(removed);
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
class InspectorTreeRow with SearchableDataMixin {
  InspectorTreeRow({
    required this.node,
    required this.index,
    required this.ticks,
    required this.depth,
    required this.lineToParent,
  });

  final InspectorTreeNode node;

  /// Column indexes of ticks to draw lines from parents to children.
  final List<int> ticks;
  final int depth;
  final int index;
  final bool lineToParent;

  bool get isSelected => node.selected;
}

/// Callback issued every time a node is added to the tree.
typedef NodeAddedCallback = void Function(
  InspectorTreeNode node,
  RemoteDiagnosticsNode diagnosticsNode,
);

class InspectorTreeConfig {
  InspectorTreeConfig({
    this.onNodeAdded,
    this.onClientActiveChange,
    this.onSelectionChange,
    this.onExpand,
  });

  final NodeAddedCallback? onNodeAdded;
  final VoidCallback? onSelectionChange;
  final void Function(bool added)? onClientActiveChange;
  final TreeEventCallback? onExpand;
}

enum SearchTargetType {
  widget,
  // TODO(https://github.com/flutter/devtools/issues/3489) implement other search scopes: details, all etc
}
