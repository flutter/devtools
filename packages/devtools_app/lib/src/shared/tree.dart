// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;

import '../primitives/auto_dispose_mixin.dart';
import '../primitives/trees.dart';
import 'collapsible_mixin.dart';
import 'theme.dart';

class TreeView<T extends TreeNode<T>> extends StatefulWidget {
  const TreeView({
    required this.dataRootsListenable,
    required this.dataDisplayProvider,
    required this.onItemSelected,
    this.onItemExpanded,
    this.shrinkWrap = false,
    this.itemExtent,
    this.onTraverse,
    this.emptyTreeViewBuilder,
    this.scrollController,
  });

  final ValueListenable<List<T>> dataRootsListenable;

  /// Use [shrinkWrap] iff you need to place a TreeView inside a ListView or
  /// other container with unconstrained height.
  ///
  /// Enabling shrinkWrap impacts performance.
  ///
  /// Defaults to false.
  final bool shrinkWrap;

  final Widget Function(T, VoidCallback) dataDisplayProvider;

  /// Invoked when a tree node is selected. If [onItemExpanded] is not
  /// provided, this method will also be called when the expand button is
  /// tapped.
  final FutureOr<void> Function(T) onItemSelected;

  /// If provided, this method will be called when the expand button is tapped.
  /// Otherwise, [onItemSelected] will be invoked, if provided.
  final FutureOr<void> Function(T)? onItemExpanded;

  final double? itemExtent;

  /// Called on traversal of child node during [buildFlatList].
  final void Function(T)? onTraverse;

  /// Builds a widget representing the empty tree. If [emptyTreeViewBuilder]
  /// is not provided, then an empty [SizedBox] will be built.
  final Widget Function()? emptyTreeViewBuilder;

  final ScrollController? scrollController;

  @override
  _TreeViewState<T> createState() => _TreeViewState<T>();
}

class _TreeViewState<T extends TreeNode<T>> extends State<TreeView<T>>
    with TreeMixin<T>, AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(widget.dataRootsListenable, _updateTreeView);
    _updateTreeView();
  }

  void _updateTreeView() {
    dataRoots = List.from(widget.dataRootsListenable.value);
    _updateItems();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return _emptyTreeViewBuilder();
    return ListView.builder(
      itemCount: items.length,
      itemExtent: widget.itemExtent,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const ClampingScrollPhysics() : null,
      controller: widget.scrollController,
      itemBuilder: (context, index) {
        final T item = items[index];
        return _TreeViewItem<T>(
          item,
          buildDisplay: (onPressed) =>
              widget.dataDisplayProvider(item, onPressed),
          onItemSelected: _onItemSelected,
          onItemExpanded: _onItemExpanded,
        );
      },
    );
  }

  Widget _emptyTreeViewBuilder() {
    if (widget.emptyTreeViewBuilder != null) {
      return widget.emptyTreeViewBuilder!();
    }
    return const SizedBox();
  }

  // TODO(kenz): animate expansions and collapses.
  void _onItemSelected(T item) async {
    // Order of execution matters for the below calls.
    if (widget.onItemExpanded == null && item.isExpandable) {
      item.toggleExpansion();
    }
    await widget.onItemSelected(item);

    _updateItems();
  }

  void _onItemExpanded(T item) async {
    if (item.isExpandable) {
      item.toggleExpansion();
    }
    if (widget.onItemExpanded != null) {
      await widget.onItemExpanded!(item);
    } else {
      await widget.onItemSelected(item);
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

class _TreeViewItem<T extends TreeNode<T>> extends StatefulWidget {
  const _TreeViewItem(
    this.data, {
    required this.buildDisplay,
    required this.onItemExpanded,
    required this.onItemSelected,
  });

  final T data;

  final Widget Function(VoidCallback onPressed) buildDisplay;

  final void Function(T) onItemSelected;
  final void Function(T) onItemExpanded;

  @override
  _TreeViewItemState<T> createState() => _TreeViewItemState<T>();
}

class _TreeViewItemState<T extends TreeNode<T>> extends State<_TreeViewItem<T>>
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
                    onTap: _onExpanded,
                    child: RotationTransition(
                      turns: expandArrowAnimation,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: defaultIconSize,
                      ),
                    ),
                  )
                : SizedBox(width: defaultIconSize),
            Expanded(child: widget.buildDisplay(_onSelected)),
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

  void _onExpanded() {
    widget.onItemExpanded(widget.data);
    setExpanded(widget.data.isExpanded);
  }

  void _onSelected() {
    widget.onItemSelected(widget.data);
    setExpanded(widget.data.isExpanded);
  }
}

mixin TreeMixin<T extends TreeNode<T>> {
  late List<T> dataRoots;

  late List<T> items;

  List<T> buildFlatList(
    List<T> roots, {
    void onTraverse(T node)?,
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
    final shouldContinue = callback(node);
    if (shouldContinue) {
      for (var child in node.children) {
        traverse(child, callback);
      }
    }
  }
}
