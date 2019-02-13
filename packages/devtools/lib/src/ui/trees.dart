// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Provides functionality for moving around a tree using the keyboard.
mixin TreeKeyboardNavigation<T> {
  List<TreeNode<T>> get treeNodes;
  TreeNode<T> get selectedItem;
  void select(TreeNode<T> node);

  void handleDownKey() {
    if (selectedItem != null) {
      final nextElm = selectedItem.getNextVisibleElement();
      if (nextElm != null) {
        select(nextElm);
      }
    } else {
      if (treeNodes.isNotEmpty) {
        select(treeNodes.first);
      }
    }
  }

  void handleUpKey() {
    if (selectedItem != null) {
      final prevElm = selectedItem.getPreviousVisibleElement();
      if (prevElm != null) {
        select(prevElm);
      }
    } else {
      if (treeNodes.isNotEmpty) {
        select(treeNodes.last.getLastVisibleDescendant() ?? treeNodes.last);
      }
    }
  }

  void handleRightKey() {
    if (!selectedItem.hasChildren) {
      return;
    }
    if (!selectedItem.isExpanded) {
      selectedItem.expand();
    } else {
      select(selectedItem.visibleChildren.first);
    }
  }

  void handleLeftKey() {
    if (selectedItem.isExpanded) {
      selectedItem.collapse();
    } else if (selectedItem.parent != null) {
      select(selectedItem.parent);
    }
  }
}

/// Provies shared functionality for trees.
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

  TreeNode<T> getNextVisibleElement({bool includeChildren = true}) {
    // The next visible element below this one is first of:
    // - Our first child
    // - Our next sibling
    // - The next sibling of our parent
    // - The next sibling of our parents parent (recursive...)
    if (includeChildren && isExpanded && visibleChildren.isNotEmpty) {
      return visibleChildren.first;
    }
    return nextSibling ?? parent?.getNextVisibleElement(includeChildren: false);
  }

  TreeNode<T> getPreviousVisibleElement() {
    // The previous visible element above this one is first of:
    // - Our previous sibling's last visible ancestor
    // - Our previous sibling
    // - Our parent

    return previousSibling?.getLastVisibleDescendant() ??
        previousSibling ??
        parent;
  }

  TreeNode<T> getLastVisibleDescendant() {
    var node = this;
    while (node.isExpanded && node.visibleChildren.isNotEmpty) {
      node = node.visibleChildren.last;
    }
    return node;
  }
}
