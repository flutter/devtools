// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_snapshot_analysis/precompiler_trace.dart';
import 'package:vm_snapshot_analysis/program_info.dart';

import '../../shared/common_widgets.dart';
import '../../shared/primitives/trees.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';

class CallGraphWithDominators extends StatefulWidget {
  const CallGraphWithDominators({super.key, required this.callGraphRoot});

  final CallGraphNode callGraphRoot;

  @override
  State<CallGraphWithDominators> createState() =>
      _CallGraphWithDominatorsState();
}

class _CallGraphWithDominatorsState extends State<CallGraphWithDominators> {
  bool showCallGraph = false;

  late DominatorTreeNode dominatorTreeRoot;

  @override
  void initState() {
    super.initState();
    dominatorTreeRoot =
        DominatorTreeNode.from(widget.callGraphRoot.dominatorRoot);
  }

  @override
  void didUpdateWidget(covariant CallGraphWithDominators oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.callGraphRoot != widget.callGraphRoot) {
      dominatorTreeRoot =
          DominatorTreeNode.from(widget.callGraphRoot.dominatorRoot);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AreaPaneHeader(
          title: Text(showCallGraph ? 'Call Graph' : 'Dominator Tree'),
          includeTopBorder: false,
          roundedTopBorder: false,
          actions: [
            const Text('Show call graph'),
            DevToolsSwitch(
              padding: const EdgeInsets.only(left: denseSpacing),
              value: showCallGraph,
              onChanged: _toggleShowCallGraph,
            ),
          ],
        ),
        Expanded(
          child: showCallGraph
              ? CallGraphView(node: widget.callGraphRoot)
              : DominatorTree(
                  dominatorTreeRoot: dominatorTreeRoot,
                  selectedNode: widget.callGraphRoot,
                ),
        ),
      ],
    );
  }

  void _toggleShowCallGraph(bool shouldShow) {
    setState(() {
      showCallGraph = shouldShow;
    });
  }
}

class CallGraphView extends StatefulWidget {
  const CallGraphView({super.key, required this.node});

  final CallGraphNode node;

  @override
  State<CallGraphView> createState() => _CallGraphViewState();
}

class _CallGraphViewState extends State<CallGraphView> {
  late CallGraphNode selectedNode;

  @override
  void initState() {
    super.initState();
    selectedNode = widget.node;
  }

  @override
  void didUpdateWidget(covariant CallGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      selectedNode = widget.node;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Padding to prevent the node title and arrows from overlapping the column
    // headers.
    const columnHeaderPadding = 50.0;
    final mainNode = Padding(
      padding: const EdgeInsets.symmetric(horizontal: columnHeaderPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: densePadding),
            child: Icon(Icons.arrow_forward),
          ),
          Flexible(
            child: DevToolsTooltip(
              message: selectedNode.data.toString(),
              child: Padding(
                padding: const EdgeInsets.all(densePadding),
                child: Text(
                  selectedNode.display,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: densePadding),
            child: Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: _CallGraphTable(
                    tableType: _CallGraphTableType.from,
                    selectedNode: selectedNode,
                    onNodeSelected: _selectMainNode,
                  ),
                ),
                const SizedBox(width: densePadding),
                Flexible(
                  child: _CallGraphTable(
                    tableType: _CallGraphTableType.to,
                    selectedNode: selectedNode,
                    onNodeSelected: _selectMainNode,
                  ),
                ),
              ],
            ),
            Positioned(
              top: densePadding,
              width: constraints.maxWidth,
              child: mainNode,
            ),
          ],
        );
      },
    );
  }

  // TODO(kenz): store the selected node in a controller and pass the notifier
  // to the tables instead of storing the [selectedNode] value in the state
  // class.
  void _selectMainNode(CallGraphNode? node) {
    setState(() {
      selectedNode = node!;
    });
  }
}

enum _CallGraphTableType {
  from,
  to;

  String get dataKey {
    switch (this) {
      case from:
        return 'call-graph-from';
      case to:
        return 'call-graph-to';
    }
  }
}

class _CallGraphTable extends StatelessWidget {
  const _CallGraphTable({
    required this.tableType,
    required this.selectedNode,
    required this.onNodeSelected,
  });

  static final _toColumn = ToColumn();
  static final _fromColumn = FromColumn();

  final _CallGraphTableType tableType;

  final CallGraphNode selectedNode;

  final void Function(CallGraphNode? node) onNodeSelected;

  ColumnData<CallGraphNode> get tableColumn =>
      tableType == _CallGraphTableType.from ? _fromColumn : _toColumn;

  @override
  Widget build(BuildContext context) {
    return FlatTable<CallGraphNode>(
      keyFactory: (CallGraphNode node) => ValueKey<CallGraphNode>(node),
      data: tableType == _CallGraphTableType.from
          ? selectedNode.pred
          : selectedNode.succ,
      dataKey: tableType.dataKey,
      columns: [tableColumn],
      onItemSelected: onNodeSelected,
      defaultSortColumn: tableColumn,
      defaultSortDirection: SortDirection.descending,
    );
  }
}

class FromColumn extends ColumnData<CallGraphNode> {
  FromColumn() : super.wide('From');

  @override
  String getValue(CallGraphNode dataObject) => dataObject.display;
}

class ToColumn extends ColumnData<CallGraphNode> {
  ToColumn() : super.wide('To');

  @override
  ColumnAlignment get alignment => ColumnAlignment.right;

  @override
  TextAlign get headerAlignment => TextAlign.right;

  @override
  String? getValue(CallGraphNode dataObject) => dataObject.display;
}

class DominatorTree extends StatelessWidget {
  DominatorTree({
    super.key,
    required this.dominatorTreeRoot,
    required this.selectedNode,
  });

  static const dominatorTreeTableKey = Key('DominatorTree - table');

  final DominatorTreeNode? dominatorTreeRoot;

  final CallGraphNode? selectedNode;

  final _packageColumn = _PackageColumn();

  @override
  Widget build(BuildContext context) {
    _expandToSelected();
    // TODO(kenz): programmatically select [selectedNode] in the table.
    return TreeTable<DominatorTreeNode>(
      key: dominatorTreeTableKey,
      dataRoots: [dominatorTreeRoot!],
      dataKey: 'dominator-tree',
      keyFactory: (node) => PageStorageKey<String>('${node.callGraphNode.id}'),
      columns: [_packageColumn],
      treeColumn: _packageColumn,
      defaultSortColumn: _packageColumn,
      defaultSortDirection: SortDirection.descending,
      autoExpandRoots: true,
    );
  }

  void _expandToSelected() {
    var selected = dominatorTreeRoot!.firstChildWithCondition(
      (node) => node.callGraphNode.id == selectedNode!.id,
    );

    while (selected != null) {
      selected.expand();
      selected = selected.parent;
    }
  }
}

class _PackageColumn extends TreeColumnData<DominatorTreeNode> {
  _PackageColumn() : super('Package');

  @override
  String getValue(DominatorTreeNode dataObject) =>
      dataObject.callGraphNode.display;
}

extension CallGraphNodeDisplay on CallGraphNode {
  String get display {
    final displayText =
        data is ProgramInfoNode ? data.qualifiedName : data.toString();
    if (displayText == '@shared') {
      // Special case '@shared' because this is the name of the call graph root,
      // and '@root' has a more intuitive meaning.
      return '@root';
    }
    return displayText;
  }

  CallGraphNode get dominatorRoot {
    var root = this;
    while (root.dominator != null) {
      root = root.dominator!;
    }
    return root;
  }
}

class DominatorTreeNode extends TreeNode<DominatorTreeNode> {
  DominatorTreeNode._(this.callGraphNode);

  factory DominatorTreeNode.from(CallGraphNode cgNode) {
    final domNode = DominatorTreeNode._(cgNode);
    for (var dominated in cgNode.dominated) {
      domNode.addChild(DominatorTreeNode.from(dominated));
    }
    return domNode;
  }

  final CallGraphNode callGraphNode;

  @override
  DominatorTreeNode shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}
