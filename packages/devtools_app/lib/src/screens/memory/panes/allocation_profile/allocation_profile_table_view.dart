// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../config_specific/import_export/import_export.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/table.dart';
import '../../../../shared/table_data.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../../vm_developer/vm_service_private_extensions.dart';
import '../../primitives/ui.dart';
import 'allocation_profile_table_view_controller.dart';

// TODO(bkonyi): ensure data displayed in this view is included in the full
// memory page export and is serializable/deserializable.

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 90.0;

class _FieldClassNameColumn extends ColumnData<ClassHeapStats> {
  _FieldClassNameColumn()
      : super(
          'Class',
          fixedWidthPx: scaleByFontFactor(200),
        );

  @override
  String? getValue(ClassHeapStats dataObject) => dataObject.classRef!.name;

  @override
  bool get supportsSorting => true;
}

/// For more information on the Dart GC implementation, see:
/// https://medium.com/flutter/flutter-dont-fear-the-garbage-collector-d69b3ff1ca30
enum _HeapGeneration {
  newSpace,
  oldSpace,
  total;

  @override
  String toString() {
    switch (this) {
      case _HeapGeneration.newSpace:
        return 'New Space';
      case _HeapGeneration.oldSpace:
        return 'Old Space';
      case _HeapGeneration.total:
        return 'Total';
    }
  }
}

class _FieldInstanceCountColumn extends ColumnData<ClassHeapStats> {
  _FieldInstanceCountColumn({required this.heap})
      : super(
          'Instances',
          titleTooltip: 'The number of instances of the class in the heap',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  final _HeapGeneration heap;

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpace.count;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpace.count;
      case _HeapGeneration.total:
        return dataObject.instancesCurrent;
    }
  }

  @override
  bool get numeric => true;
}

class _FieldExternalSizeColumn extends _FieldSizeColumn {
  _FieldExternalSizeColumn({required super.heap})
      : super._(
          title: 'External',
          titleTooltip: 'Portion of memory allocated outside of the Dart heap',
        );

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpace.externalSize;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpace.externalSize;
      case _HeapGeneration.total:
        return dataObject.newSpace.externalSize +
            dataObject.oldSpace.externalSize;
    }
  }
}

class _FieldInternalSizeColumn extends _FieldSizeColumn {
  _FieldInternalSizeColumn({required super.heap})
      : super._(
          title: 'Internal',
          titleTooltip: 'Portion of memory allocated within the Dart heap',
        );

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpace.size;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpace.size;
      case _HeapGeneration.total:
        return dataObject.bytesCurrent!;
    }
  }
}

class _FieldSizeColumn extends ColumnData<ClassHeapStats> {
  factory _FieldSizeColumn({required heap}) => _FieldSizeColumn._(
        title: 'Size',
        titleTooltip: 'Total memory allocated',
        heap: heap,
      );

  _FieldSizeColumn._({
    required String title,
    required String titleTooltip,
    required this.heap,
  }) : super(
          title,
          titleTooltip: titleTooltip,
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  final _HeapGeneration heap;

  @override
  dynamic getValue(ClassHeapStats dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpace.size + dataObject.newSpace.externalSize;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpace.size + dataObject.oldSpace.externalSize;
      case _HeapGeneration.total:
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
}

/// Displays data from an [AllocationProfile] in a tabular format, with support
/// for refreshing the data on a garbage collection (GC) event and exporting
/// [AllocationProfile]'s to a CSV formatted file.
class AllocationProfileTableView extends StatefulWidget {
  const AllocationProfileTableView({super.key, required this.controller});

  @override
  State<AllocationProfileTableView> createState() =>
      AllocationProfileTableViewState();

  final AllocationProfileTableViewController controller;
}

class AllocationProfileTableViewState
    extends State<AllocationProfileTableView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AllocationProfileTableControls(
          allocationProfileController: widget.controller,
        ),
        const SizedBox(
          height: denseRowSpacing,
        ),
        Expanded(
          child: _AllocationProfileTable(
            controller: widget.controller,
          ),
        ),
      ],
    );
  }
}

class _AllocationProfileTable extends StatefulWidget {
  const _AllocationProfileTable({
    Key? key,
    required this.controller,
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

  static final _initialSortColumn = _FieldSizeColumn(
    heap: _HeapGeneration.total,
  );

  static final _columns = [
    _FieldClassNameColumn(),
    _FieldInstanceCountColumn(heap: _HeapGeneration.total),
    _initialSortColumn,
    _FieldInternalSizeColumn(heap: _HeapGeneration.total),
    _FieldExternalSizeColumn(heap: _HeapGeneration.total),
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
    _FieldInstanceCountColumn(heap: _HeapGeneration.newSpace),
    _FieldSizeColumn(heap: _HeapGeneration.newSpace),
    _FieldInternalSizeColumn(heap: _HeapGeneration.newSpace),
    _FieldExternalSizeColumn(heap: _HeapGeneration.newSpace),
    _FieldInstanceCountColumn(heap: _HeapGeneration.oldSpace),
    _FieldSizeColumn(heap: _HeapGeneration.oldSpace),
    _FieldInternalSizeColumn(heap: _HeapGeneration.oldSpace),
    _FieldExternalSizeColumn(heap: _HeapGeneration.oldSpace),
  ];

  final AllocationProfileTableViewController controller;

  @override
  State<_AllocationProfileTable> createState() =>
      _AllocationProfileTableState();
}

class _AllocationProfileTableState extends State<_AllocationProfileTable> {
  // TODO(bkonyi): pull state into a TableController class.
  // See https://github.com/flutter/devtools/issues/4365
  late SortDirection _sortDirection;
  late ColumnData<ClassHeapStats> _sortColumn;

  @override
  void initState() {
    super.initState();
    _sortColumn = _AllocationProfileTable._initialSortColumn;
    _sortDirection = SortDirection.descending;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AllocationProfile?>(
      valueListenable: widget.controller.currentAllocationProfile,
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
              padding: EdgeInsets.zero,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FlatTable<ClassHeapStats?>(
                    columnGroups: [
                      ..._AllocationProfileTable._columnGroups,
                      if (vmDeveloperModeEnabled)
                        ..._AllocationProfileTable._vmDeveloperModeColumnGroups,
                    ],
                    columns: [
                      ..._AllocationProfileTable._columns,
                      if (vmDeveloperModeEnabled)
                        ..._AllocationProfileTable._vmDeveloperModeColumns,
                    ],
                    data: profile.members!.where(
                      (element) {
                        return element.bytesCurrent != 0 ||
                            element.newSpace.externalSize != 0 ||
                            element.oldSpace.externalSize != 0;
                      },
                    ).toList(),
                    sortColumn: _sortColumn,
                    sortDirection: _sortDirection,
                    onSortChanged: (
                      sortColumn,
                      direction, {
                      secondarySortColumn,
                    }) {
                      setState(() {
                        sortColumn = sortColumn;
                        _sortDirection = direction;
                      });
                    },
                    onItemSelected: (item) => null,
                    keyFactory: (element) => Key(element!.classRef!.name!),
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
  }) : super(key: key);

  final AllocationProfileTableViewController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ExportAllocationProfileButton(
          allocationProfileController: allocationProfileController,
        ),
        const SizedBox(width: denseSpacing),
        RefreshButton.icon(
          onPressed: allocationProfileController.refresh,
        ),
        const SizedBox(width: denseSpacing),
        _RefreshOnGCToggleButton(
          allocationProfileController: allocationProfileController,
        ),
        const _ProfileHelpLink(),
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
    return ValueListenableBuilder<AllocationProfile?>(
      valueListenable: allocationProfileController.currentAllocationProfile,
      builder: (context, currentAllocationProfile, _) {
        return IconLabelButton(
          label: 'CSV',
          icon: Icons.file_download,
          tooltip: 'Download allocation profile data in CSV format',
          onPressed: currentAllocationProfile == null
              ? null
              : () {
                  final file = allocationProfileController
                      .downloadMemoryTableCsv(currentAllocationProfile);
                  notificationService.push(successfulExportMessage(file));
                },
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
        );
      },
    );
  }
}

class _RefreshOnGCToggleButton extends StatelessWidget {
  const _RefreshOnGCToggleButton({
    Key? key,
    required this.allocationProfileController,
  }) : super(key: key);

  final AllocationProfileTableViewController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: allocationProfileController.refreshOnGc,
      builder: (context, refreshOnGc, _) {
        return ToggleButton(
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

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = 'allocationProfile';

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: analytics_constants.memory,
      gaSelection:
          analytics_constants.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Allocation Profile Help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('The allocation profile tab displays information about\n'
              'allocated objects in the Dart heap of the selected\n'
              'isolate.'),
          MoreInfoLink(
            url: 'https://github.com/flutter/devtools/blob/master/'
                'packages/devtools_app/lib/src/screens/memory/panes/'
                'allocation_profile/ALLOCATION_PROFILE.md',
            gaScreenName: '',
            gaSelectedItemDescription:
                analytics_constants.topicDocumentationLink(_documentationTopic),
          )
        ],
      ),
    );
  }
}
