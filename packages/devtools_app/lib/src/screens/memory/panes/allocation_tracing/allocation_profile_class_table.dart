// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_controller.dart';
import '../../../../shared/table/table_data.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import 'allocation_profile_tracing_view_controller.dart';

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 80.0;

class _TraceCheckBoxColumn extends ColumnData<TracedClass>
    implements ColumnRenderer<TracedClass> {
  _TraceCheckBoxColumn({required this.controller})
      : super(
          'Trace',
          titleTooltip:
              'Enable or disable allocation tracing for a specific type',
          fixedWidthPx: scaleByFontFactor(55.0),
          alignment: ColumnAlignment.left,
        );

  final AllocationProfileTracingViewController controller;

  @override
  bool get supportsSorting => false;

  @override
  Widget build(
    BuildContext context,
    TracedClass item, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return Checkbox(
      value: item.traceAllocations,
      onChanged: (value) async {
        ga.select(
          analytics_constants.memory,
          '${analytics_constants.MemoryEvent.tracingTraceCheck}-$value',
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

class _ClassNameColumn extends ColumnData<TracedClass> {
  _ClassNameColumn() : super.wide('Class');

  @override
  String? getValue(TracedClass stats) => stats.cls.name;

  @override
  bool get supportsSorting => true;
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
  const AllocationTracingTable({required this.controller});

  final AllocationProfileTracingViewController controller;

  @override
  State<AllocationTracingTable> createState() => _AllocationTracingTableState();
}

class _AllocationTracingTableState extends State<AllocationTracingTable> {
  late final _TraceCheckBoxColumn _checkboxColumn;
  static final _classNameColumn = _ClassNameColumn();
  static final _instancesColumn = _InstancesColumn();

  late final List<ColumnData<TracedClass>> columns;

  @override
  void initState() {
    super.initState();
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
      analytics_constants.memory,
      analytics_constants.MemoryEvent.tracingClassFilter,
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
          child: DualValueListenableBuilder<bool,
              AllocationProfileTracingIsolateState>(
            firstListenable: widget.controller.refreshing,
            secondListenable: widget.controller.stateForIsolate,
            builder: (context, _, state, __) {
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
                    selectionNotifier: state.selectedTracedClass,
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
