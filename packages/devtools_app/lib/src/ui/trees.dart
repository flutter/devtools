// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Provides functionality for navigating around a tree.
mixin TreeNavigator<T> {
  List<TreeNode<T>> get treeNodes;
  TreeNode<T> get selectedItem;
  void select(TreeNode<T> node);

  void moveDown() {
    if (selectedItem != null) {
      final nextElm = _getNextVisibleElementBelow(selectedItem);
      if (nextElm != null) {
        select(nextElm);
      }
    } else {
      if (treeNodes.isNotEmpty) {
        select(treeNodes.first);
      }
    }
  }

  void moveUp() {
    if (selectedItem != null) {
      final prevElm = _getPreviousVisibleElementAbove(selectedItem);
      if (prevElm != null) {
        select(prevElm);
      }
    } else {
      if (treeNodes.isNotEmpty) {
        select(_getLastVisibleDescendant(treeNodes.last) ?? treeNodes.last);
      }
    }
  }

  void moveRight() {
    if (!selectedItem.hasChildren) {
      return;
    }
    if (!selectedItem.isExpanded) {
      selectedItem.expand();
    } else {
      select(selectedItem.visibleChildren.first);
    }
  }

  void moveLeft() {
    if (selectedItem.isExpanded) {
      selectedItem.collapse();
    } else if (selectedItem.parent != null) {
      select(selectedItem.parent);
    }
  }

  TreeNode<T> _getNextVisibleElementBelow(TreeNode<T> node,
      {bool includeChildren = true}) {
    // The next visible element below this one is first of:
    // - Our first child
    // - Our next sibling
    // - The next sibling of our parent
    // - The next sibling of our parents parent (recursive...)
    if (includeChildren && node.isExpanded && node.visibleChildren.isNotEmpty) {
      return node.visibleChildren.first;
    }
    return node.nextSibling ??
        (node.parent != null
            ? _getNextVisibleElementBelow(node.parent, includeChildren: false)
            : null);
  }

  TreeNode<T> _getPreviousVisibleElementAbove(TreeNode<T> node) {
    // The previous visible element above this one is first of:
    // - Our previous sibling's last visible descendant
    // - Our previous sibling
    // - Our parent

    return node.previousSibling != null
        ? _getLastVisibleDescendant(node.previousSibling) ??
            node.previousSibling ??
            node.parent
        : node.parent;
  }

  TreeNode<T> _getLastVisibleDescendant(TreeNode<T> node) {
    while (node.isExpanded && node.visibleChildren.isNotEmpty) {
      node = node.visibleChildren.last;
    }
    return node;
  }
}

/// Provides shared functionality for trees.
class Tree<T> {
  // Connects parents, children and sibling nodes required to be able to traverse
  // the tree.
  void connectNodes(
    TreeNode<T> parent,
    List<TreeNode<T>> children,
    bool Function(T) hasChildren,
  ) {
    TreeNode<T> previousNode;

    for (TreeNode<T> node in children) {
      node.parent = parent;
      node.hasChildren = hasChildren(node.data);

      if (previousNode != null) {
        node.previousSibling = previousNode;
        previousNode.nextSibling ??= node;
      }

      previousNode = node;
    }

    parent?.children?.addAll(children);
  }
}

/// Represents a node in a tree that holds some [data].
class TreeNode<T> {
  TreeNode(this.data);
  T data;
  bool isExpanded = false, hasChildren = false;
  Function() expand, collapse;
  TreeNode<T> parent;
  TreeNode<T> previousSibling, nextSibling;
  final List<TreeNode<T>> children = [];
  List<TreeNode<T>> get visibleChildren => isExpanded ? children : [];
}
