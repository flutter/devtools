// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'elements.dart';

mixin TreeKeyboardNavigation<T> {
  List<TreeNode<T>> get treeNodes;
  TreeNode<T> get selectedItem;
  void select(TreeNode<T> node);

  void handleKeyPress(KeyboardEvent e) {
    if (e.keyCode == KeyCode.DOWN) {
      _handleDownKey();
    } else if (e.keyCode == KeyCode.UP) {
      _handleUpKey();
    } else if (e.keyCode == KeyCode.RIGHT) {
      _handleRightKey();
    } else if (e.keyCode == KeyCode.LEFT) {
      _handleLeftKey();
    } else {
      return; // don't preventDefault if we were anything else.
    }

    e.preventDefault();
  }

  void _handleDownKey() {
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

  void _handleUpKey() {
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

  void _handleRightKey() {
    if (!selectedItem.hasChildren) {
      return;
    }
    if (!selectedItem.isExpanded) {
      selectedItem.expand();
    } else {
      select(selectedItem.visibleChildren.first);
    }
  }

  void _handleLeftKey() {
    if (selectedItem.isExpanded) {
      selectedItem.collapse();
    } else if (selectedItem.parent != null) {
      select(selectedItem.parent);
    }
  }
}

class TreeNode<T> extends CoreElement {
  TreeNode(CoreElement core, this.item) : super.from(core.element);
  final T item;
  bool isExpanded = false, hasChildren = false;
  Function() expand, collapse;
  TreeNode<T> parent;
  TreeNode<T> previousSibling, nextSibling;
  final List<TreeNode<T>> children = [];
  List<TreeNode<T>> get visibleChildren => isExpanded ? children : [];

  TreeNode<T> getNextVisibleElement({includeChildren = true}) {
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
