// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart' hide Stack;

import 'collapsible_mixin.dart';
import 'theme.dart';
import 'trees.dart';

class TreeView<T extends TreeNode<T>> extends StatefulWidget {
  const TreeView({
    this.dataRoots,
    this.dataDisplayProvider,
    this.onItemPressed,
    this.shrinkWrap = false,
    this.itemExtent,
    this.onTraverse,
  });

  final List<T> dataRoots;

  /// Use [shrinkWrap] iff you need to place a TreeView inside a ListView or
  /// other container with unconstrained height.
  ///
  /// Enabling shrinkWrap impacts performance.
  ///
  /// Defaults to false.
  final bool shrinkWrap;

  final Widget Function(T, VoidCallback) dataDisplayProvider;

  final FutureOr<void> Function(T) onItemPressed;

  final double itemExtent;

  /// Called on traversal of child node during [buildFlatList].
  final void Function(T) onTraverse;

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
      itemExtent: widget.itemExtent,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const ClampingScrollPhysics() : null,
      itemBuilder: (context, index) {
        final item = items[index];
        return TreeViewItem<T>(
          item,
          buildDisplay: (onPressed) =>
              widget.dataDisplayProvider(item, onPressed),
          onItemPressed: _onItemPressed,
        );
      },
    );
  }

  // TODO(kenz): animate expansions and collapses.
  void _onItemPressed(T item) async {
    // Order of execution matters for the below calls.
    if (item.isExpandable) {
      item.toggleExpansion();
    }
    if (widget.onItemPressed != null) {
      await widget.onItemPressed(item);
    }
    _updateItems();
  }

  void _updateItems() {
    setState(() {
      items = buildFlatList(
        dataRoots,
        onTraverse: widget.onTraverse,
      );
    });
  }
}

class TreeViewItem<T extends TreeNode<T>> extends StatefulWidget {
  const TreeViewItem(this.data, {this.buildDisplay, this.onItemPressed});

  final T data;

  final Widget Function(VoidCallback onPressed) buildDisplay;

  final void Function(T) onItemPressed;

  @override
  _TreeViewItemState<T> createState() => _TreeViewItemState<T>();
}

class _TreeViewItemState<T extends TreeNode<T>> extends State<TreeViewItem<T>>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: nodeIndent(widget.data)),
      child: Container(
        color:
            widget.data.isSelected ? Theme.of(context).selectedRowColor : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.data.isExpandable
                ? InkWell(
                    onTap: _onPressed,
                    child: RotationTransition(
                      turns: expandArrowAnimation,
                      child: const Icon(
                        Icons.arrow_drop_down,
                        size: defaultIconSize,
                      ),
                    ),
                  )
                : const SizedBox(width: defaultIconSize),
            Expanded(child: widget.buildDisplay(_onPressed)),
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

  List<T> buildFlatList(
    List<T> roots, {
    void onTraverse(T node),
  }) {
    final flatList = <T>[];
    for (T root in roots) {
      traverse(root, (n) {
        if (onTraverse != null) onTraverse(n);
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
