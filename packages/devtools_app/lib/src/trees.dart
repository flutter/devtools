// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

/// Non-UI specific tree code should live in this file.
///
/// This file does not have direct dependencies on dart:html and therefore
/// allows for testing to be done on the VM.

// TODO(kenz): look into consolidating logic between this file and
// ui/trees.dart, which houses generic tree types vs the base classes in this
// file.

class TreeNode<T extends TreeNode<T>> {
  T parent;

  final List<T> children = [];

  /// Index in [parent.children].
  int index = -1;

  /// Depth of this tree, including [this].
  ///
  /// We assume that TreeNodes are not modified after the first time [depth] is
  /// accessed. We would need to clear the cache before accessing, otherwise.
  int get depth {
    if (_depth != 0) {
      return _depth;
    }
    for (T child in children) {
      _depth = max(_depth, child.depth);
    }
    return _depth = _depth + 1;
  }

  int _depth = 0;

  bool get isRoot => parent == null;

  T get root {
    if (_root != null) {
      return _root;
    }

    // Store nodes we have visited so we can cache the root value for each one
    // once we find the root.
    final visited = {this};

    T root = this;
    while (root.parent != null) {
      visited.add(root);
      root = root.parent;
    }

    // Set [_root] for all nodes we visited.
    for (T node in visited) {
      node._root = root;
    }

    return root;
  }

  T _root;

  /// The level (0-based) of this tree node in the tree.
  int get level {
    if (_level != null) {
      return _level;
    }
    int level = 0;
    T current = this;
    while (current.parent != null) {
      current = current.parent;
      level++;
    }
    return _level = level;
  }

  int _level;

  /// Whether the tree table node is expandable.
  bool get isExpandable => children.isNotEmpty;

  /// Whether the node is currently expanded in the tree table.
  bool get isExpanded => _isExpanded;
  bool _isExpanded = false;

  void expand() {
    _isExpanded = true;
  }

  // TODO(jacobr): cache the value of whether the node should be shown
  // so that lookups on this class are O(1) invalidating the cache when nodes
  // up the tree are expanded and collapsed.
  /// Whether this node should be shown in the tree.
  ///
  /// When using this, consider caching the value. It is O([level]) to compute.
  bool shouldShow() {
    return parent == null || (parent.isExpanded && parent.shouldShow());
  }

  void collapse() {
    _isExpanded = false;
  }

  void addChild(T child) {
    children.add(child);
    child.parent = this;
    child.index = children.length - 1;
  }

  /// Expands this node and all of its children (cascading).
  void expandCascading() {
    breadthFirstTraversal<T>(this, action: (T node) {
      node.expand();
    });
  }

  /// Collapses this node and all of its children (cascading).
  void collapseCascading() {
    breadthFirstTraversal<T>(this, action: (T node) {
      node.collapse();
    });
  }

  bool containsChildWithCondition(bool condition(T node)) {
    final T childWithCondition = firstChildWithCondition(condition);
    return childWithCondition != null;
  }

  T firstChildWithCondition(bool condition(T node)) {
    return breadthFirstTraversal<T>(
      this,
      returnCondition: condition,
    );
  }

  T firstNodeAtLevel(int level) {
    if (level >= depth) return null;
    var node = this;
    while (node.level < level) {
      // Walk down the tree until we find the node at [level].
      if (node.children.isNotEmpty) {
        // Since we have already ensured that [level] < [depth], at least one
        // child is guaranteed to meet the firstWhere condition.
        node = node.children.firstWhere((n) => n.depth > level - n.level);
      }
    }
    return node;
  }
}

/// Traverses a tree in breadth-first order.
///
/// [returnCondition] specifies the condition for which we should stop
/// traversing the tree. For example, if we are calling this method to perform
/// BFS, [returnCondition] would specify when we have found the node we are
/// searching for. [action] specifies an action that we will execute on each
/// node. For example, if we need to traverse a tree and change a property on
/// every single node, we would do this through the [action] param.
T breadthFirstTraversal<T extends TreeNode<T>>(
  T root, {
  bool returnCondition(T node),
  void action(T node),
}) {
  final queue = Queue.of([root]);
  while (queue.isNotEmpty) {
    final node = queue.removeFirst();
    if (returnCondition != null && returnCondition(node)) {
      return node;
    }
    if (action != null) {
      action(node);
    }
    node.children.forEach(queue.add);
  }
  return null;
}
