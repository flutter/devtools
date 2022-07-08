import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../devtools_app.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';

// TODO(bkonyi): guard the members in this file based on VM developer mode state.
import '../vm_developer/vm_service_private_extensions.dart';

class FieldClassName extends ColumnData<ClassHeapStats> {
  FieldClassName() : super.wide('Class');

  @override
  String? getValue(ClassHeapStats dataObject) => dataObject.classRef!.name;

  @override
  String getDisplayValue(ClassHeapStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapStats a, ClassHeapStats b) {
    final Comparable valueA = getValue(a)!;
    final Comparable valueB = getValue(b)!;
    return valueA.compareTo(valueB);
  }
}

enum HeapGeneration {
  newSpace,
  oldSpace,
  total;

  @override
  String toString() {
    switch (this) {
      case HeapGeneration.newSpace:
        return 'New Space';
      case HeapGeneration.oldSpace:
        return 'Old Space';
      case HeapGeneration.total:
        return 'Total';
    }
  }
}

class DividerColumn extends ColumnData<ClassHeapStats> {
  DividerColumn()
      : super(
          '',
          alignment: ColumnAlignment.center,
          fixedWidthPx: 50,
        );

  @override
  dynamic getValue(ClassHeapStats dataObject) => null;

  @override
  String getDisplayValue(ClassHeapStats dataObject) => '';

  @override
  bool get supportsSorting => false;

  @override
  int compare(ClassHeapStats a, ClassHeapStats b) => -1;
}

class FieldInstanceCountColumn extends ColumnData<ClassHeapStats> {
  FieldInstanceCountColumn({required this.heap})
      : super(
          'Instances',
          alignment: ColumnAlignment.right,
          fixedWidthPx: 100,
        );

  final HeapGeneration heap;

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpace.count;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpace.count;
      case HeapGeneration.total:
        return dataObject.instancesCurrent;
    }
  }

  @override
  String getDisplayValue(ClassHeapStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get numeric => true;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapStats a, ClassHeapStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class FieldExternalSizeColumn extends FieldSizeColumn {
  FieldExternalSizeColumn({required super.heap})
      : super._(
          title: 'External',
        );

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpace.externalSize;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpace.externalSize;
      case HeapGeneration.total:
        return dataObject.newSpace.externalSize +
            dataObject.oldSpace.externalSize;
    }
  }
}

class FieldInternalSizeColumn extends FieldSizeColumn {
  FieldInternalSizeColumn({required super.heap})
      : super._(
          title: 'Internal',
        );

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpace.size;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpace.size;
      case HeapGeneration.total:
        return dataObject.bytesCurrent!;
    }
  }
}

class FieldSizeColumn extends ColumnData<ClassHeapStats> {
  factory FieldSizeColumn({required heap}) => FieldSizeColumn._(
        title: 'Size',
        heap: heap,
      );

  FieldSizeColumn._({
    required String title,
    required this.heap,
  }) : super.wide(
          title,
          alignment: ColumnAlignment.right,
        );

  final HeapGeneration heap;

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    print(dataObject.json!.keys);
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpace.size + dataObject.newSpace.externalSize;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpace.size + dataObject.oldSpace.externalSize;
      case HeapGeneration.total:
        return dataObject.bytesCurrent! +
            dataObject.newSpace.externalSize +
            dataObject.oldSpace.externalSize;
    }
  }

  @override
  String getDisplayValue(ClassHeapStats dataObject) => prettyPrintBytes(
        getValue(dataObject),
        includeUnit: true,
        kbFractionDigits: 1,
      )!;

  @override
  String getTooltip(ClassHeapStats dataObject) => '${getValue(dataObject)} B';

  @override
  bool get numeric => true;

  @override
  bool get supportsSorting => true;

  @override
  int compare(ClassHeapStats a, ClassHeapStats b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class MemoryTableView extends StatefulWidget {
  @override
  State<MemoryTableView> createState() => _MemoryTableViewState();
}

class _MemoryTableViewState extends State<MemoryTableView>
    with ProvidedControllerMixin<MemoryController, MemoryTableView> {
  final _columns = [
    FieldClassName(),
    FieldInstanceCountColumn(heap: HeapGeneration.total),
    FieldSizeColumn(heap: HeapGeneration.total),
    FieldInternalSizeColumn(heap: HeapGeneration.total),
    FieldExternalSizeColumn(heap: HeapGeneration.total),
    FieldInstanceCountColumn(heap: HeapGeneration.newSpace),
    FieldSizeColumn(heap: HeapGeneration.newSpace),
    FieldInternalSizeColumn(heap: HeapGeneration.newSpace),
    FieldExternalSizeColumn(heap: HeapGeneration.newSpace),
    FieldInstanceCountColumn(heap: HeapGeneration.oldSpace),
    FieldSizeColumn(heap: HeapGeneration.oldSpace),
    FieldInternalSizeColumn(heap: HeapGeneration.oldSpace),
    FieldExternalSizeColumn(heap: HeapGeneration.oldSpace),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = serviceManager.service!;
    return Card(
      elevation: 5,
      child: ValueListenableBuilder<IsolateRef?>(
        valueListenable: serviceManager.isolateManager.selectedIsolate,
        builder: (context, isolate, _) {
          return FutureBuilder<AllocationProfile>(
            future: service.getAllocationProfile(isolate!.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container();
              }
              return Expanded(
                child: FlatTable<ClassHeapStats?>(
                  columnGroups: [
                    ColumnGroup(
                      title: '',
                      range: const Range(0, 1),
                    ),
                    ColumnGroup(
                      title: 'Total',
                      range: const Range(1, 5),
                    ),
                    ColumnGroup(
                      title: 'New Space',
                      range: const Range(5, 9),
                    ),
                    ColumnGroup(
                      title: 'Old Space',
                      range: const Range(9, 13),
                    ),
                  ],
                  columns: _columns,
                  data: snapshot.data!.members!.where(
                    (element) {
                      print(element.json!.keys.toList());
                      return element.bytesCurrent != 0 ||
                          element.newSpace.externalSize != 0 ||
                          element.oldSpace.externalSize != 0;
                    },
                  ).toList(),
                  sortColumn: _columns.first,
                  sortDirection: SortDirection.ascending,
                  /*tableDataController: TableDataController<ClassHeapStats>(
                    data: snapshot.data!.members!
                        .where(
                          (element) =>
                              element.bytesCurrent != 0 ||
                              element.newSpace.externalSize != 0 ||
                              element.oldSpace.externalSize != 0,
                        )
                        .toList(),
                    sortColumn: _columns.first,
                    sortDirection: SortDirection.ascending,
                  ),*/
                  onItemSelected: (item) => null,
                  keyFactory: (d) => Key(d!.classRef!.name!),
                  /*activeSearchMatchNotifier:
                      controller.searchMatchMonitorAllocationsNotifier,*/
                ),
              );
            },
          );
        },
      ),
    );
  }
}
