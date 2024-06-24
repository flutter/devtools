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
final treeNodePrimaryDescriptionPattern = RegExp(r'^([\w ]+)(.*)$');
// TODO(jacobr): temporary workaround for missing structure from assertion thrown building
// widget errors.
final assertionThrownBuildingError = RegExp(
  r'^(The following assertion was thrown building [a-zA-Z]+)(\(.*\))(:)$',
);

typedef TreeEventCallback = void Function(InspectorTreeNode node);

const iconPadding = 4.0;
const chartLineStrokeWidth = 1.0;
double get inspectorColumnIndent => scaleByFontFactor(24.0);
double get inspectorRowHeight => scaleByFontFactor(20.0);

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
      for (final child in children) {
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

  bool get showExpandCollapse {
    return diagnostic?.hasChildren == true || children.isNotEmpty;
  }

  set isExpanded(bool value) {
    if (value != _isExpanded) {
      _isExpanded = value;
      isDirty = true;
      if (_shouldShow ?? false) {
        for (final child in children) {
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

  List<InspectorTreeRow> buildRows() {
    final rows = <InspectorTreeRow>[];

    void buildRowsHelper(
      InspectorTreeNode node, {
      required int depth,
      required List<int> ticks,
    }) {
      final currentIdx = rows.length;

      rows.add(
        InspectorTreeRow(
          node: node,
          index: currentIdx,
          ticks: ticks,
          depth: depth,
          lineToParent: !node.isProperty &&
              currentIdx != 0 &&
              node.parent!.showLinesToChildren,
          hasSingleChild: node.children.length == 1,
        ),
      );

      final style = node.diagnostic?.style;
      final indented = style != DiagnosticsTreeStyle.flat &&
          style != DiagnosticsTreeStyle.error;

      if (!node.isExpanded) return;
      final children = node.children;
      final parentDepth = depth;
      final childrenDepth = children.length > 1 ? parentDepth + 1 : parentDepth;
      for (final child in children) {
        final shouldAddTick = children.length > 1 &&
            children.last != child &&
            !children.last.isProperty &&
            indented;

        buildRowsHelper(
          child,
          depth: childrenDepth,
          ticks: [
            ...ticks,
            if (shouldAddTick) parentDepth,
          ],
        );
      }
    }

    buildRowsHelper(this, depth: 0, ticks: <int>[]);
    return rows;
  }

  bool get hasPlaceholderChildren {
    return children.length == 1 && children.first.diagnostic == null;
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
    required this.hasSingleChild,
  });

  final InspectorTreeNode node;

  /// Column indexes of ticks to draw lines from parents to children.
  final List<int> ticks;
  final int depth;
  final int index;
  final bool lineToParent;
  final bool hasSingleChild;

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
