// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../shared/primitives/utils.dart';
import '../../../../shared/profiler_utils.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_data.dart';
import 'method_table_controller.dart';
import 'method_table_model.dart';

final _methodColumnMinWidth = scaleByFontFactor(800.0);

/// Widget that displays a method table for a CPU profile.
class CpuMethodTable extends StatelessWidget {
  const CpuMethodTable({super.key, required this.methodTableController});

  final MethodTableController methodTableController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MethodTableGraphNode>>(
      valueListenable: methodTableController.methods,
      builder: (context, methods, _) {
        return SplitPane(
          axis: Axis.horizontal,
          initialFractions: const [0.5, 0.5],
          children: [
            MethodTable(methodTableController, methods),
            _MethodGraph(methodTableController),
          ],
        );
      },
    );
  }
}

// TODO(kenz): ensure that this table automatically scrolls to the selected
// node from [MethodTableController].
/// A table of methods and their timing information for a CPU profile.
@visibleForTesting
class MethodTable extends StatelessWidget {
  const MethodTable(this._methodTableController, this._methods, {super.key});

  static final methodColumn = _MethodColumn();
  static final selfTimeColumn = _SelfTimeColumn();
  static final totalTimeColumn = _TotalTimeColumn();
  static final columns = List<ColumnData<MethodTableGraphNode>>.unmodifiable([
    totalTimeColumn,
    selfTimeColumn,
    methodColumn,
  ]);

  final MethodTableController _methodTableController;

  final List<MethodTableGraphNode> _methods;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration.onlyRight(
      child: SearchableFlatTable<MethodTableGraphNode>(
        searchController: _methodTableController,
        keyFactory: (node) => ValueKey(node.id),
        data: _methods,
        dataKey: 'cpu-profile-methods',
        columns: columns,
        defaultSortColumn: totalTimeColumn,
        defaultSortDirection: SortDirection.descending,
        sortOriginalData: true,
        selectionNotifier: _methodTableController.selectedNode,
        sizeColumnsToFit: false,
      ),
    );
  }
}

/// A graph for a single method that shows its predecessors (callers) and
/// successors (callees) as well as timing information for each of those nodes.
class _MethodGraph extends StatefulWidget {
  const _MethodGraph(this.methodTableController);

  final MethodTableController methodTableController;

  @override
  State<_MethodGraph> createState() => _MethodGraphState();
}

class _MethodGraphState extends State<_MethodGraph> with AutoDisposeMixin {
  MethodTableGraphNode? _selectedGraphNode;

  List<MethodTableGraphNode> _callers = [];

  List<MethodTableGraphNode> _callees = [];

  @override
  void initState() {
    super.initState();

    _initGraphNodes();
    addAutoDisposeListener(widget.methodTableController.selectedNode, () {
      setState(() {
        _initGraphNodes();
      });
    });
  }

  void _initGraphNodes() {
    _selectedGraphNode = widget.methodTableController.selectedNode.value;
    if (_selectedGraphNode == null) {
      _callers = <MethodTableGraphNode>[];
      _callees = <MethodTableGraphNode>[];
    } else {
      _callers = _selectedGraphNode!.predecessors
          .cast<MethodTableGraphNode>()
          .toList();
      _callees =
          _selectedGraphNode!.successors.cast<MethodTableGraphNode>().toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedNode = _selectedGraphNode;
    if (selectedNode == null) {
      return OutlineDecoration.onlyLeft(
        child: const Center(
          child: Text('Select a method to view its call graph.'),
        ),
      );
    }
    final selectedNodeDisplay = selectedNode.display;
    return OutlineDecoration.onlyLeft(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: OutlineDecoration.onlyBottom(
              child: _CallersTable(
                widget.methodTableController,
                _callers,
              ),
            ),
          ),
          DevToolsTooltip(
            message: selectedNodeDisplay,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: denseSpacing,
                vertical: densePadding,
              ),
              child: MethodAndSourceDisplay(
                methodName: selectedNode.name,
                packageUri: selectedNode.packageUri,
                sourceLine: selectedNode.sourceLine,
                displayInRow: false,
              ),
            ),
          ),
          Flexible(
            child: OutlineDecoration.onlyTop(
              child: _CalleesTable(
                widget.methodTableController,
                _callees,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A table of predecessors (callers) for a single method in a method table.
class _CallersTable extends StatelessWidget {
  _CallersTable(this._methodTableController, this._callers) {
    _callerTimeColumn =
        _CallerTimeColumn(methodTableController: _methodTableController);
    columns = List<ColumnData<MethodTableGraphNode>>.unmodifiable([
      _callerTimeColumn,
      methodColumn,
    ]);
  }

  static final methodColumn = _MethodColumn();

  final MethodTableController _methodTableController;

  final List<MethodTableGraphNode> _callers;

  late final List<ColumnData<MethodTableGraphNode>> columns;

  late final _CallerTimeColumn _callerTimeColumn;

  @override
  Widget build(BuildContext context) {
    return FlatTable<MethodTableGraphNode>(
      keyFactory: (node) => ValueKey('caller-${node.id}'),
      data: _callers,
      dataKey: 'cpu-profile-method-callers',
      columns: columns,
      defaultSortColumn: _callerTimeColumn,
      defaultSortDirection: SortDirection.descending,
      selectionNotifier: _methodTableController.selectedNode,
      sizeColumnsToFit: false,
    );
  }
}

/// A table of successors (callees) for a single method in a method table.
class _CalleesTable extends StatelessWidget {
  _CalleesTable(this._methodTableController, this._callees) {
    _calleeTimeColumn =
        _CalleeTimeColumn(methodTableController: _methodTableController);
    _columns = List<ColumnData<MethodTableGraphNode>>.unmodifiable([
      _calleeTimeColumn,
      _methodColumn,
    ]);
  }

  static final _methodColumn = _MethodColumn();

  final MethodTableController _methodTableController;

  final List<MethodTableGraphNode> _callees;

  late final List<ColumnData<MethodTableGraphNode>> _columns;

  late final _CalleeTimeColumn _calleeTimeColumn;

  @override
  Widget build(BuildContext context) {
    return FlatTable<MethodTableGraphNode>(
      keyFactory: (node) => ValueKey('callee-${node.id}'),
      data: _callees,
      dataKey: 'cpu-profile-method-callees',
      columns: _columns,
      defaultSortColumn: _calleeTimeColumn,
      defaultSortDirection: SortDirection.descending,
      selectionNotifier: _methodTableController.selectedNode,
      sizeColumnsToFit: false,
    );
  }
}

class _MethodColumn extends ColumnData<MethodTableGraphNode>
    implements ColumnRenderer<MethodTableGraphNode> {
  _MethodColumn()
      : super.wide(
          'Method',
          minWidthPx: _methodColumnMinWidth,
        );

  @override
  bool get supportsSorting => true;

  @override
  String getValue(MethodTableGraphNode dataObject) => dataObject.name;

  @override
  String getDisplayValue(MethodTableGraphNode dataObject) => dataObject.display;

  @override
  String getTooltip(MethodTableGraphNode dataObject) => dataObject.display;

  @override
  Widget? build(
    BuildContext context,
    MethodTableGraphNode data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return MethodAndSourceDisplay(
      methodName: data.name,
      packageUri: data.packageUri,
      sourceLine: data.sourceLine,
    );
  }
}

const _totalAndSelfColumnWidth = 60.0;
const _callGraphColumnWidth = 70.0;

class _SelfTimeColumn extends TimeAndPercentageColumn<MethodTableGraphNode> {
  _SelfTimeColumn({String? titleTooltip})
      : super(
          title: 'Self %',
          titleTooltip: titleTooltip,
          percentageOnly: true,
          timeProvider: (node) => node.selfTime,
          percentAsDoubleProvider: (node) => node.selfTimeRatio,
          secondaryCompare: (node) => node.name,
          columnWidth: _totalAndSelfColumnWidth,
        );
}

class _TotalTimeColumn extends TimeAndPercentageColumn<MethodTableGraphNode> {
  _TotalTimeColumn({String? titleTooltip})
      : super(
          title: 'Total %',
          titleTooltip: titleTooltip,
          percentageOnly: true,
          timeProvider: (node) => node.totalTime,
          percentAsDoubleProvider: (node) => node.totalTimeRatio,
          secondaryCompare: (node) => node.name,
          columnWidth: _totalAndSelfColumnWidth,
        );
}

class _CallerTimeColumn extends TimeAndPercentageColumn<MethodTableGraphNode> {
  _CallerTimeColumn({
    required MethodTableController methodTableController,
    String? titleTooltip,
  }) : super(
          title: 'Caller %',
          titleTooltip: titleTooltip,
          percentageOnly: true,
          percentAsDoubleProvider: (node) =>
              methodTableController.callerPercentageFor(node),
          secondaryCompare: (node) => node.name,
          columnWidth: _callGraphColumnWidth,
        );
}

class _CalleeTimeColumn extends TimeAndPercentageColumn<MethodTableGraphNode> {
  _CalleeTimeColumn({
    required MethodTableController methodTableController,
    String? titleTooltip,
  }) : super(
          title: 'Callee %',
          titleTooltip: titleTooltip,
          percentageOnly: true,
          percentAsDoubleProvider: (node) =>
              methodTableController.calleePercentageFor(node),
          secondaryCompare: (node) => node.name,
          columnWidth: _callGraphColumnWidth,
        );
}
