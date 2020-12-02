// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_snapshot_analysis/precompiler_trace.dart';
import 'package:vm_snapshot_analysis/program_info.dart';

import '../common_widgets.dart';
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../trees.dart';
import '../utils.dart';

class CallGraphWithDominators extends StatefulWidget {
  const CallGraphWithDominators({@required this.callGraphRoot});

  final CallGraphNode callGraphRoot;

  @override
  _CallGraphWithDominatorsState createState() =>
      _CallGraphWithDominatorsState();
}

class _CallGraphWithDominatorsState extends State<CallGraphWithDominators> {
  bool showCallGraph = false;

  DominatorTreeNode dominatorTreeRoot;

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
        areaPaneHeader(
          context,
          title: showCallGraph ? 'Call Graph' : 'Dominator Tree',
          needsTopBorder: false,
          needsBottomBorder: false,
          needsLeftBorder: true,
          actions: [
            const Text('Show call graph'),
            Switch(
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
  const CallGraphView({@required this.node});

  static const Key fromTableKey = Key('CallGraphView - From table');
  static const Key toTableKey = Key('CallGraphView - To table');

  final CallGraphNode node;

  @override
  _CallGraphViewState createState() => _CallGraphViewState();
}

class _CallGraphViewState extends State<CallGraphView> {
  final _fromColumn = FromColumn();

  final _toColumn = ToColumn();

  CallGraphNode selectedNode;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: _buildFromTable(),
                ),
                Container(
                  height: constraints.maxHeight,
                  width: densePadding,
                  color: titleSolidBackgroundColor(Theme.of(context)),
                ),
                Flexible(
                  child: _buildToTable(),
                ),
              ],
            ),
            Positioned(
              top: 0,
              width: constraints.maxWidth,
              child: _buildMainNode(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFromTable() {
    return FlatTable<CallGraphNode>(
      key: CallGraphView.fromTableKey,
      columns: [_fromColumn],
      data: selectedNode.pred,
      keyFactory: (CallGraphNode node) => ValueKey<CallGraphNode>(node),
      onItemSelected: _selectMainNode,
      sortColumn: _fromColumn,
      sortDirection: SortDirection.descending,
    );
  }

  Widget _buildToTable() {
    return FlatTable<CallGraphNode>(
      key: CallGraphView.toTableKey,
      columns: [_toColumn],
      data: selectedNode.succ,
      keyFactory: (CallGraphNode node) => ValueKey<CallGraphNode>(node),
      onItemSelected: _selectMainNode,
      sortColumn: _toColumn,
      sortDirection: SortDirection.descending,
    );
  }

  Widget _buildMainNode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: densePadding),
          child: Icon(Icons.arrow_forward),
        ),
        Tooltip(
          waitDuration: tooltipWait,
          message: selectedNode.data.toString(),
          child: Container(
            padding: const EdgeInsets.all(densePadding),
            child: Text(
              selectedNode.display,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: densePadding),
          child: Icon(Icons.arrow_forward),
        ),
      ],
    );
  }

  void _selectMainNode(CallGraphNode node) {
    setState(() {
      selectedNode = node;
    });
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
  String getValue(CallGraphNode dataObject) => dataObject.display;
}

class DominatorTree extends StatelessWidget {
  DominatorTree({
    @required this.dominatorTreeRoot,
    @required this.selectedNode,
  });

  static const dominatorTreeTableKey = Key('DominatorTree - table');

  final DominatorTreeNode dominatorTreeRoot;

  final CallGraphNode selectedNode;

  final _packageColumn = _PackageColumn();

  @override
  Widget build(BuildContext context) {
    _expandToSelected();
    // TODO(kenz): programmatically select [selectedNode] in the table.
    return TreeTable<DominatorTreeNode>(
      key: dominatorTreeTableKey,
      dataRoots: [dominatorTreeRoot],
      columns: [_packageColumn],
      treeColumn: _packageColumn,
      keyFactory: (node) => PageStorageKey<String>('${node.callGraphNode.id}'),
      sortColumn: _packageColumn,
      sortDirection: SortDirection.descending,
      autoExpandRoots: true,
    );
  }

  void _expandToSelected() {
    var selected = dominatorTreeRoot.firstChildWithCondition(
        (node) => node.callGraphNode.id == selectedNode.id);

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
      root = root.dominator;
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
}
