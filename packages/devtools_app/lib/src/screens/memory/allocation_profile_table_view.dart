// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../devtools_app.dart';
import '../../config_specific/import_export/import_export.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';

import '../vm_developer/vm_service_private_extensions.dart';
import 'allocation_profile_table_view_controller.dart';
import 'panes/control/constants.dart';

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 80.0;

class FieldClassName extends ColumnData<ClassHeapStats> {
  FieldClassName()
      : super(
          'Class',
          fixedWidthPx: scaleByFontFactor(200),
        );

  @override
  String? getValue(ClassHeapStats dataObject) => dataObject.classRef!.name;

  @override
  String getDisplayValue(ClassHeapStats dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;
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

class FieldInstanceCountColumn extends ColumnData<ClassHeapStats> {
  FieldInstanceCountColumn({required this.heap})
      : super(
          'Instances',
          titleTooltip: 'The number of instances of the class in the heap',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
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
}

class FieldExternalSizeColumn extends FieldSizeColumn {
  FieldExternalSizeColumn({required super.heap})
      : super._(
          title: 'External',
          titleTooltip: 'Portion of memory allocated outside of the Dart heap',
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
          titleTooltip: 'Portion of memory allocated within the Dart heap',
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
        titleTooltip: 'Total memory allocated',
        heap: heap,
      );

  FieldSizeColumn._({
    required String title,
    required String titleTooltip,
    required this.heap,
  }) : super(
          title,
          titleTooltip: titleTooltip,
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  final HeapGeneration heap;

  @override
  dynamic getValue(ClassHeapStats dataObject) {
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
}

/// Displays data from an [AllocationProfile] in a tabular format, with support
/// for refreshing the data on a garbage collection (GC) event and exporting
/// [AllocationProfile]'s to a CSV formatted file.
class AllocationProfileTableView extends StatefulWidget {
  @override
  State<AllocationProfileTableView> createState() =>
      AllocationProfileTableViewState();
}

class AllocationProfileTableViewState extends State<AllocationProfileTableView>
    with ProvidedControllerMixin<MemoryController, AllocationProfileTableView> {
  @visibleForTesting
  static const refreshOnGcKey = Key('Refresh on GC Key');
  @visibleForTesting
  static const refreshKey = Key('Refresh Allocation Profile Key');
  @visibleForTesting
  static final searchFieldKey =
      GlobalKey(debugLabel: 'Allocation Profile Search Field Key');

  late AllocationProfileTableViewController allocationProfileController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) {
      return;
    }
    allocationProfileController = controller.allocationProfileController
      ..initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AllocationProfileTableControls(
          allocationProfileController: allocationProfileController,
          refreshOnGcKey: refreshOnGcKey,
          refreshKey: refreshKey,
        ),
        const SizedBox(height: denseRowSpacing,),
        Expanded(
          child: _AllocationProfileTable(
            allocationProfileController: allocationProfileController,
          ),
        ),
      ],
    );
  }
}

class _AllocationProfileTable extends StatelessWidget {
  const _AllocationProfileTable({
    Key? key,
    required this.allocationProfileController,
  }) : super(key: key);

  /// List of columns that are displayed regardless of VM developer mode state.
  static final _columnGroups = [
    ColumnGroup(
      title: '',
      range: const Range(0, 1),
    ),
    ColumnGroup(
      title: 'Total',
      range: const Range(1, 5),
    ),
  ];

  static final _columns = [
    FieldClassName(),
    FieldInstanceCountColumn(heap: HeapGeneration.total),
    FieldSizeColumn(heap: HeapGeneration.total),
    FieldInternalSizeColumn(heap: HeapGeneration.total),
    FieldExternalSizeColumn(heap: HeapGeneration.total),
  ];

  /// Columns for data that is only displayed with VM developer mode enabled.
  static final _vmDeveloperModeColumnGroups = [
    ColumnGroup(
      title: 'New Space',
      range: const Range(5, 9),
    ),
    ColumnGroup(
      title: 'Old Space',
      range: const Range(9, 13),
    ),
  ];

  static final _vmDeveloperModeColumns = [
    FieldInstanceCountColumn(heap: HeapGeneration.newSpace),
    FieldSizeColumn(heap: HeapGeneration.newSpace),
    FieldInternalSizeColumn(heap: HeapGeneration.newSpace),
    FieldExternalSizeColumn(heap: HeapGeneration.newSpace),
    FieldInstanceCountColumn(heap: HeapGeneration.oldSpace),
    FieldSizeColumn(heap: HeapGeneration.oldSpace),
    FieldInternalSizeColumn(heap: HeapGeneration.oldSpace),
    FieldExternalSizeColumn(heap: HeapGeneration.oldSpace),
  ];

  final AllocationProfileTableViewController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AllocationProfile?>(
      valueListenable: allocationProfileController.currentAllocationProfile,
      builder: (context, profile, _) {
        // TODO(bkonyi): make this an overlay so the table doesn't
        // disappear when we're retrieving new data, especially since the
        // spinner animation freezes when retrieving the profile.
        if (profile == null) {
          return const CenteredCircularProgressIndicator();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: preferences.vmDeveloperModeEnabled,
          builder: (context, vmDeveloperModeEnabled, _) {
            return ElevatedCard(
              padding: const EdgeInsets.only(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FlatTable<ClassHeapStats?>(
                    columnGroups: [
                      ..._columnGroups,
                      if (vmDeveloperModeEnabled)
                        ..._vmDeveloperModeColumnGroups,
                    ],
                    columns: [
                      ..._columns,
                      if (vmDeveloperModeEnabled) ..._vmDeveloperModeColumns,
                    ],
                    data: profile.members!.where(
                      (element) {
                        return element.bytesCurrent != 0 ||
                            element.newSpace.externalSize != 0 ||
                            element.oldSpace.externalSize != 0;
                      },
                    ).toList(),
                    sortColumn: _columns.first,
                    sortDirection: SortDirection.ascending,
                    onItemSelected: (item) => null,
                    keyFactory: (d) => Key(d!.classRef!.name!),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _AllocationProfileTableControls extends StatelessWidget {
  const _AllocationProfileTableControls({
    Key? key,
    required this.allocationProfileController,
    this.refreshOnGcKey,
    this.refreshKey,
  }) : super(key: key);

  final AllocationProfileTableViewController allocationProfileController;
  final Key? refreshOnGcKey;
  final Key? refreshKey;

  @override
  Widget build(BuildContext context) {
    return Row(    
      children: [
        _ExportAllocationProfileButton(
          allocationProfileController: allocationProfileController,
        ),
        const SizedBox(width: denseSpacing),
        OutlinedIconButton(
          key: refreshKey,
          icon: Icons.refresh,
          onPressed: () => allocationProfileController.refresh(),
        ),
        const SizedBox(width: denseSpacing),
        _RefreshOnGCToggleButton(
          allocationProfileController: allocationProfileController,
          refreshOnGcKey: refreshOnGcKey,
        ),
      ],
    );
  }
}

class _ExportAllocationProfileButton extends StatelessWidget {
  const _ExportAllocationProfileButton({
    Key? key,
    required this.allocationProfileController,
  }) : super(key: key);

  final AllocationProfileTableViewController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return ExportButton(
      onPressed: () {
        final profile =
            allocationProfileController.currentAllocationProfile.value;
        if (profile == null) {
          return;
        }
        final file =
            allocationProfileController.downloadMemoryTableCsv(profile);
        Notifications.of(context)!.push(successfulExportMessage(file));
      },
      minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
    );
  }
}

class _RefreshOnGCToggleButton extends StatelessWidget {
  const _RefreshOnGCToggleButton({
    Key? key,
    required this.allocationProfileController,
    this.refreshOnGcKey,
  }) : super(key: key);

  final AllocationProfileTableViewController allocationProfileController;
  final Key? refreshOnGcKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: allocationProfileController.refreshOnGc,
      builder: (context, refreshOnGc, _) {
        return ToggleButton(
          key: refreshOnGcKey,
          message: 'Auto-refresh on garbage collection',
          label: const Text('Refresh on GC'),
          icon: Icons.autorenew_outlined,
          isSelected: refreshOnGc,
          onPressed: allocationProfileController.toggleRefreshOnGc,
        );
      },
    );
  }
}
