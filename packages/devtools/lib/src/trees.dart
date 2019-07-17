// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

/// Non-UI specific tree code should live in this file.
///
/// This file does not have direct dependencies on dart:html and therefore
/// allows for testing to be done on the VM.

// TODO(kenzie): look into consolidating logic between this file and
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

  T get root {
    if (_root != null) {
      return _root;
    }
    T root = this;
    while (root.parent != null) {
      root = root.parent;
    }
    return _root = root;
  }

  T _root;

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

  /// The level (0-based) of this tree node in the tree.
  int _level;

  void addChild(T child) {
    children.add(child);
    child.parent = this;
    child.index = children.length - 1;
  }

  bool containsChildWithCondition(bool condition(T node)) {
    final Queue<T> queue = Queue.from([this]);
    while (queue.isNotEmpty) {
      final T node = queue.removeFirst();
      if (condition(node)) {
        return true;
      }
      node.children.forEach(queue.add);
    }
    return false;
  }

  /// Whether the tree table node is expandable.
  bool get isExpandable => children.isNotEmpty;

  /// Whether the node is currently expanded in the tree table.
  bool isExpanded = false;
}
