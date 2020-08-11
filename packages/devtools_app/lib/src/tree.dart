// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;

import 'collapsible_mixin.dart';
import 'theme.dart';
import 'trees.dart';

class TreeView<T extends TreeNode<T>> extends StatefulWidget {
  const TreeView({
    this.dataRoots,
    this.dataDisplayProvider,
    this.onItemPressed,
  });

  final List<T> dataRoots;

  final Widget Function(T) dataDisplayProvider;

  final void Function(T) onItemPressed;

  @override
  _TreeViewState<T> createState() => _TreeViewState<T>();
}

class _TreeViewState<T extends TreeNode<T>> extends State<TreeView<T>>
    with TreeMixin<T> {
  @override
  void initState() {
    super.initState();
    _initData();
    _updateItems();
  }

  @override
  void didUpdateWidget(TreeView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataRoots != oldWidget.dataRoots) {
      _initData();
      _updateItems();
    }
  }

  void _initData() {
    dataRoots = List.from(widget.dataRoots);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox();
    return ListView.builder(
      itemCount: items.length,
      itemExtent: defaultListItemHeight,
      itemBuilder: (context, index) {
        final item = items[index];
        return TreeViewItem<T>(
          item,
          display: widget.dataDisplayProvider(item),
          onItemPressed: _onItemPressed,
        );
      },
    );
  }

  // TODO(kenz): animate expansions and collapses.
  void _onItemPressed(T item) {
    if (!item.isExpandable) return;

    // Order of execution matters for the below calls.
    item.toggleExpansion();
    if (widget.onItemPressed != null) {
      widget.onItemPressed(item);
    }
    _updateItems();
  }

  void _updateItems() {
    setState(() {
      items = buildFlatList(dataRoots);
    });
  }
}

class TreeViewItem<T extends TreeNode<T>> extends StatefulWidget {
  const TreeViewItem(this.data, {this.display, this.onItemPressed});

  final T data;

  final Widget display;

  final void Function(T) onItemPressed;

  @override
  _TreeViewItemState<T> createState() => _TreeViewItemState<T>();
}

class _TreeViewItemState<T extends TreeNode<T>> extends State<TreeViewItem<T>>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onPressed,
      child: Padding(
        padding: EdgeInsets.only(left: nodeIndent(widget.data)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.data.isExpandable
                ? RotationTransition(
                    turns: expandArrowAnimation,
                    child: const Icon(
                      Icons.arrow_drop_down,
                      size: defaultIconSize,
                    ),
                  )
                : const SizedBox(width: defaultIconSize),
            Expanded(child: widget.display),
          ],
        ),
      ),
    );
  }

  @override
  bool get isExpanded => widget.data.isExpanded;

  @override
  void onExpandChanged(bool expanded) {}

  @override
  bool shouldShow() => widget.data.shouldShow();

  double nodeIndent(T dataObject) {
    return dataObject.level * defaultSpacing;
  }

  void _onPressed() {
    widget.onItemPressed(widget.data);
    setExpanded(widget.data.isExpanded);
  }
}

mixin TreeMixin<T extends TreeNode<T>> {
  List<T> dataRoots;

  List<T> items;

  List<T> buildFlatList(List<T> roots) {
    final flatList = <T>[];
    for (T root in roots) {
      traverse(root, (n) {
        flatList.add(n);
        return n.isExpanded;
      });
    }
    return flatList;
  }

  void traverse(T node, bool Function(T) callback) {
    if (node == null) return;
    final shouldContinue = callback(node);
    if (shouldContinue) {
      for (var child in node.children) {
        traverse(child, callback);
      }
    }
  }
}
