// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_controller.dart';
import '../../../../shared/table/table_data.dart';
import '../../shared/widgets/shared_memory_widgets.dart';
import 'tracing_data.dart';
import 'tracing_pane_controller.dart';

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 70.0;

class _TraceCheckBoxColumn extends ColumnData<TracedClass>
    implements ColumnRenderer<TracedClass> {
  _TraceCheckBoxColumn({required this.controller})
      : super(
          'Trace',
          titleTooltip:
              'Enable or disable allocation tracing for a specific type',
          fixedWidthPx: scaleByFontFactor(40.0),
          alignment: ColumnAlignment.left,
        );

  final TracePaneController controller;

  @override
  bool get supportsSorting => false;

  @override
  Widget build(
    BuildContext context,
    TracedClass item, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return Checkbox(
      value: item.traceAllocations,
      onChanged: (value) async {
        ga.select(
          gac.memory,
          '${gac.MemoryEvent.tracingTraceCheck}-$value',
        );
        await controller.setAllocationTracingForClass(item.cls, value!);
      },
    );
  }

  @override
  bool? getValue(TracedClass _) {
    return null;
  }

  @override
  int compare(TracedClass a, TracedClass b) {
    return a.traceAllocations.boolCompare(b.traceAllocations);
  }
}

class _ClassNameColumn extends ColumnData<TracedClass>
    implements ColumnRenderer<TracedClass> {
  _ClassNameColumn({required this.rootPackage}) : super.wide('Class');

  @override
  String? getValue(TracedClass stats) => stats.cls.name;

  // We are removing the tooltip, because it is provided by [HeapClassView].
  @override
  String getTooltip(TracedClass dataObject) => '';

  final String? rootPackage;

  @override
  bool get supportsSorting => true;

  @override
  Widget build(
    BuildContext context,
    TracedClass data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return HeapClassView(
      theClass: data.name,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvent.diffClassSingleCopy,
      rootPackage: rootPackage,
    );
  }
}

class _InstancesColumn extends ColumnData<TracedClass> {
  _InstancesColumn()
      : super(
          'Delta',
          titleTooltip:
              'Number of instances, allocated after the class was selected for tracing.',
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  @override
  int getValue(TracedClass dataObject) {
    return dataObject.instances;
  }

  @override
  bool get numeric => true;
}

class AllocationTracingTable extends StatefulWidget {
  const AllocationTracingTable({super.key, required this.controller});

  final TracePaneController controller;

  @override
  State<AllocationTracingTable> createState() => _AllocationTracingTableState();
}

class _AllocationTracingTableState extends State<AllocationTracingTable> {
  late final _TraceCheckBoxColumn _checkboxColumn;
  late final _ClassNameColumn _classNameColumn;
  static final _instancesColumn = _InstancesColumn();

  late final List<ColumnData<TracedClass>> columns;

  @override
  void initState() {
    super.initState();

    _classNameColumn =
        _ClassNameColumn(rootPackage: widget.controller.rootPackage);

    _checkboxColumn = _TraceCheckBoxColumn(controller: widget.controller);
    columns = <ColumnData<TracedClass>>[
      _checkboxColumn,
      _classNameColumn,
      _instancesColumn,
    ];
  }

  // How often the ga event should be sent if the user keeps editing the filter.
  static const _editFilterGaThrottling = Duration(seconds: 5);
  DateTime _editFilterGaSent = DateTime.fromMillisecondsSinceEpoch(0);
  void _sendFilterEditGaEvent() {
    final now = DateTime.now();
    if (now.difference(_editFilterGaSent) < _editFilterGaThrottling) return;
    ga.select(
      gac.memory,
      gac.MemoryEvent.tracingClassFilter,
    );
    _editFilterGaSent = now;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: DevToolsClearableTextField(
            labelText: 'Class Filter',
            hintText: 'Filter by class name',
            onChanged: (value) {
              _sendFilterEditGaEvent();
              widget.controller.updateClassFilter(value);
            },
            controller: widget.controller.textEditingController,
          ),
        ),
        Expanded(
          child: MultiValueListenableBuilder(
            listenables: [
              widget.controller.refreshing,
              widget.controller.selection,
            ],
            builder: (context, values, __) {
              final state = values.second as TracingIsolateState;
              return ValueListenableBuilder<List<TracedClass>>(
                valueListenable: state.filteredClassList,
                builder: (context, filteredClassList, _) {
                  return FlatTable<TracedClass>(
                    keyFactory: (e) => Key(e.cls.id!),
                    data: filteredClassList,
                    dataKey: 'allocation-tracing',
                    columns: columns,
                    defaultSortColumn: _classNameColumn,
                    defaultSortDirection: SortDirection.ascending,
                    selectionNotifier: state.selectedClass,
                    pinBehavior: FlatTablePinBehavior.pinOriginalToTop,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
