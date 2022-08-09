import 'package:flutter/material.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/table.dart';
import '../../../../shared/table_data.dart';
import '../../../../shared/utils.dart';
import 'allocation_profile_tracing_view_controller.dart';

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 80.0;

class _TrackCheckBox extends ColumnData<TracedClass>
    implements ColumnRenderer<TracedClass> {
  _TrackCheckBox({
    required this.controller,
    required this.setState,
  }) : super(
          'Track',
          titleTooltip: 'Track Class Allocations',
          fixedWidthPx: scaleByFontFactor(55.0),
          alignment: ColumnAlignment.left,
        );

  final AllocationProfileTracingViewController controller;

  /// The `setState` function for [AllocationTracingTable], used to trigger a
  /// rebuild of the table when allocation tracing is enabled or disabled as a
  /// result of a checkbox state change in this column.
  final Function(Function()) setState;

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
      value: controller.isAllocationTracingEnabledForClass(item.cls),
      onChanged: (value) async {
        // Do the async work before calling `setState`, otherwise we'll get
        // flaky behavior.
        await controller.setAllocationTracingForClass(item.cls, value!);
        setState(() {});
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

class _AllocationTracingTableClassName extends ColumnData<TracedClass> {
  _AllocationTracingTableClassName()
      : super.wide(
          'Class',
        );

  @override
  String? getValue(TracedClass stats) => stats.cls.name;

  @override
  bool get supportsSorting => true;
}

class _AllocationTracingTableInstances extends ColumnData<TracedClass> {
  _AllocationTracingTableInstances()
      : super(
          'Instances',
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
  late final List<ColumnData<TracedClass>> columns;
  SortDirection sortDirection = SortDirection.ascending;
  late ColumnData<TracedClass> trackColumn;
  late ColumnData<TracedClass> secondarySortColumn;

  @override
  void initState() {
    super.initState();
    columns = <ColumnData<TracedClass>>[
      _TrackCheckBox(
        controller: widget.controller,
        setState: setState,
      ),
      _AllocationTracingTableClassName(),
      _AllocationTracingTableInstances(),
    ];
    trackColumn = columns[0];
    secondarySortColumn = columns[1];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.refreshing,
      builder: (context, _, __) {
        return FlatTable<TracedClass>(
          columns: columns,
          data: widget.controller.classList,
          keyFactory: (e) => Key(e.cls.id!),
          onItemSelected: (stats) {
            final selected = widget.controller.selectedTracedClass.value;
            // Clear the selection if the current selection is clicked again.
            widget.controller.selectTracedClass(
              selected == stats ? null : stats,
            );
          },
          sortColumn: trackColumn,
          secondarySortColumn: secondarySortColumn,
          sortDirection: sortDirection,
          selectionNotifier: widget.controller.selectedTracedClass,
          onSortChanged: (column, direction, {secondarySortColumn}) {
            // Keep track of sorting state so it doesn't get reset when
            // `controller.refreshing` changes.
            setState(() {
              sortDirection = direction;
              secondarySortColumn = secondarySortColumn;
            });
          },
        );
      },
    );
  }
}
