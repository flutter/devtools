// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;

import 'collapsible_mixin.dart';
import 'primitives/trees.dart';

double get defaultTreeViewRowHeight => scaleByFontFactor(20.0);

class TreeView<T extends TreeNode<T>> extends StatefulWidget {
  const TreeView({
    super.key,
    required this.dataRootsListenable,
    required this.dataDisplayProvider,
    this.onItemSelected,
    this.onItemExpanded,
    this.onTraverse,
    this.emptyTreeViewBuilder,
    this.scrollController,
    this.includeScrollbar = false,
    this.isSelectable = true,
  });

  final ValueListenable<List<T>> dataRootsListenable;

  final Widget Function(T, VoidCallback) dataDisplayProvider;

  /// Invoked when a tree node is selected. If [onItemExpanded] is not
  /// provided, this method will also be called when the expand button is
  /// tapped.
  final FutureOr<void> Function(T)? onItemSelected;

  /// If provided, this method will be called when the expand button is tapped.
  /// Otherwise, [onItemSelected] will be invoked, if provided.
  final FutureOr<void> Function(T)? onItemExpanded;

  /// Called on traversal of child node during [buildFlatList].
  final void Function(T)? onTraverse;

  /// Builds a widget representing the empty tree. If [emptyTreeViewBuilder]
  /// is not provided, then an empty [SizedBox] will be built.
  final Widget Function()? emptyTreeViewBuilder;

  final ScrollController? scrollController;

  final bool includeScrollbar;

  final bool isSelectable;

  @override
  State<TreeView<T>> createState() => _TreeViewState<T>();
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
    dataRoots = List.of(widget.dataRootsListenable.value);
    _updateItems();
  }

  @override
  Widget build(BuildContext context) {
    if (dataFlatList.isEmpty) return _emptyTreeViewBuilder();
    final content = SizedBox(
      height: dataFlatList.length * defaultTreeViewRowHeight,
      child: _maybeWrapInSelectionArea(
        ListView.builder(
          itemCount: dataFlatList.length,
          itemExtent: defaultTreeViewRowHeight,
          physics: const ClampingScrollPhysics(),
          controller: widget.scrollController,
          itemBuilder: (context, index) {
            final T item = dataFlatList[index];
            return _TreeViewItem<T>(
              item,
              buildDisplay: (onPressed) =>
                  widget.dataDisplayProvider(item, onPressed),
              onItemSelected: _onItemSelected,
              onItemExpanded: _onItemExpanded,
            );
          },
        ),
      ),
    );
    if (widget.includeScrollbar) {
      return Scrollbar(
        thumbVisibility: true,
        controller: widget.scrollController,
        child: content,
      );
    }
    return content;
  }

  Widget _emptyTreeViewBuilder() {
    if (widget.emptyTreeViewBuilder != null) {
      return widget.emptyTreeViewBuilder!();
    }
    return const SizedBox();
  }

  Widget _maybeWrapInSelectionArea(Widget tree) {
    if (widget.isSelectable) {
      return SelectionArea(child: tree);
    }
    return tree;
  }

  // TODO(kenz): animate expansions and collapses.
  void _onItemSelected(T item) async {
    // Order of execution matters for the below calls.
    if (widget.onItemExpanded == null && item.isExpandable) {
      item.toggleExpansion();
    }
    if (widget.onItemSelected != null) {
      await widget.onItemSelected!(item);
    }

    _updateItems();
  }

  void _onItemExpanded(T item) async {
    if (item.isExpandable) {
      item.toggleExpansion();
    }
    if (widget.onItemExpanded != null) {
      await widget.onItemExpanded!(item);
    } else if (widget.onItemSelected != null) {
      await widget.onItemSelected!(item);
    }
    _updateItems();
  }

  void _updateItems() {
    setState(() {
      dataFlatList = buildFlatList(
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
    return Container(
      margin: EdgeInsets.only(left: nodeIndent(widget.data)),
      color: widget.data.isSelected
          ? Theme.of(context).colorScheme.selectedRowBackgroundColor
          : null,
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

  late List<T> dataFlatList;
}
