// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../analytics/analytics.dart' as ga;
import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_controller.dart';
import '../../../../shared/table/table_data.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../primitives/simple_elements.dart';
import '../../primitives/ui.dart';
import 'allocation_profile_table_view_controller.dart';
import 'model.dart';

// TODO(bkonyi): ensure data displayed in this view is included in the full
// memory page export and is serializable/deserializable.

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 90.0;

class _FieldClassNameColumn extends ColumnData<AllocationProfileRecord> {
  _FieldClassNameColumn()
      : super(
          'Class',
          fixedWidthPx: scaleByFontFactor(200),
        );

  @override
  String? getValue(AllocationProfileRecord dataObject) =>
      dataObject.heapClass.className;

  @override
  String getTooltip(AllocationProfileRecord dataObject) =>
      dataObject.heapClass.fullName;

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

class _FieldInstanceCountColumn extends ColumnData<AllocationProfileRecord> {
  _FieldInstanceCountColumn({required this.heap})
      : super(
          'Instances',
          titleTooltip: 'The number of instances of the class in the heap',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  final _HeapGeneration heap;

  @override
  dynamic getValue(AllocationProfileRecord dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpaceInstances;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpaceInstances;
      case _HeapGeneration.total:
        return dataObject.totalInstances;
    }
  }

  @override
  bool get numeric => true;
}

class _FieldExternalSizeColumn extends _FieldSizeColumn {
  _FieldExternalSizeColumn({required super.heap})
      : super._(
          title: 'External',
          titleTooltip:
              'Non-Dart heap allocated memory associated with a Dart object',
        );

  @override
  dynamic getValue(AllocationProfileRecord dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpaceExternalSize;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpaceExternalSize;
      case _HeapGeneration.total:
        return dataObject.totalExternalSize;
    }
  }
}

class _FieldDartHeapSizeColumn extends _FieldSizeColumn {
  _FieldDartHeapSizeColumn({required super.heap})
      : super._(
          title: 'Dart Heap',
          titleTooltip: shallowSizeColumnTooltip,
        );

  @override
  dynamic getValue(AllocationProfileRecord dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpaceDartHeapSize;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpaceDartHeapSize;
      case _HeapGeneration.total:
        return dataObject.totalDartHeapSize;
    }
  }
}

class _FieldSizeColumn extends ColumnData<AllocationProfileRecord> {
  factory _FieldSizeColumn({required heap}) => _FieldSizeColumn._(
        title: 'Total Size',
        titleTooltip: "The sum of the type's total shallow memory "
            'consumption in the Dart heap and associated external (e.g., '
            'non-Dart heap) allocations',
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
  dynamic getValue(AllocationProfileRecord dataObject) {
    switch (heap) {
      case _HeapGeneration.newSpace:
        return dataObject.newSpaceSize;
      case _HeapGeneration.oldSpace:
        return dataObject.oldSpaceSize;
      case _HeapGeneration.total:
        return dataObject.totalSize;
    }
  }

  @override
  String getDisplayValue(AllocationProfileRecord dataObject) =>
      prettyPrintBytes(
        getValue(dataObject),
        includeUnit: true,
        kbFractionDigits: 1,
      ) ??
      '';

  @override
  String getTooltip(AllocationProfileRecord dataObject) =>
      '${getValue(dataObject)} B';

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

class _AllocationProfileTable extends StatelessWidget {
  const _AllocationProfileTable({
    Key? key,
    required this.controller,
  }) : super(key: key);

  /// List of columns displayed in VM developer mode state.
  static final _vmModeColumnGroups = [
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
  ];

  static final _initialSortColumn = _FieldSizeColumn(
    heap: _HeapGeneration.total,
  );

  static final _columns = [
    _FieldClassNameColumn(),
    _FieldInstanceCountColumn(heap: _HeapGeneration.total),
    _initialSortColumn,
    _FieldDartHeapSizeColumn(heap: _HeapGeneration.total),
    _FieldExternalSizeColumn(heap: _HeapGeneration.total),
  ];

  static final _vmDeveloperModeColumns = [
    _FieldInstanceCountColumn(heap: _HeapGeneration.newSpace),
    _FieldSizeColumn(heap: _HeapGeneration.newSpace),
    _FieldDartHeapSizeColumn(heap: _HeapGeneration.newSpace),
    _FieldExternalSizeColumn(heap: _HeapGeneration.newSpace),
    _FieldInstanceCountColumn(heap: _HeapGeneration.oldSpace),
    _FieldSizeColumn(heap: _HeapGeneration.oldSpace),
    _FieldDartHeapSizeColumn(heap: _HeapGeneration.oldSpace),
    _FieldExternalSizeColumn(heap: _HeapGeneration.oldSpace),
  ];

  final AllocationProfileTableViewController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdaptedAllocationProfile?>(
      valueListenable: controller.currentAllocationProfile,
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
                  return FlatTable<AllocationProfileRecord>(
                    keyFactory: (element) => Key(element.heapClass.fullName),
                    data: profile.records,
                    dataKey: 'allocation-profile',
                    columnGroups: vmDeveloperModeEnabled
                        ? _AllocationProfileTable._vmModeColumnGroups
                        : null,
                    columns: [
                      ..._AllocationProfileTable._columns,
                      if (vmDeveloperModeEnabled)
                        ..._AllocationProfileTable._vmDeveloperModeColumns,
                    ],
                    defaultSortColumn:
                        _AllocationProfileTable._initialSortColumn,
                    defaultSortDirection: SortDirection.descending,
                    pinBehavior: FlatTablePinBehavior.pinOriginalToTop,
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
          onPressed: () async {
            ga.select(
              analytics_constants.memory,
              analytics_constants.MemoryEvent.profileRefreshManual,
            );
            await allocationProfileController.refresh();
          },
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
    return ValueListenableBuilder<AdaptedAllocationProfile?>(
      valueListenable: allocationProfileController.currentAllocationProfile,
      builder: (context, currentAllocationProfile, _) {
        return ToCsvButton(
          minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
          tooltip: 'Download allocation profile data in CSV format',
          onPressed: currentAllocationProfile == null
              ? null
              : () => allocationProfileController
                  .downloadMemoryTableCsv(currentAllocationProfile),
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
          label: 'Refresh on GC',
          icon: Icons.autorenew_outlined,
          isSelected: refreshOnGc,
          onPressed: () {
            allocationProfileController.toggleRefreshOnGc();
            ga.select(
              analytics_constants.memory,
              '${analytics_constants.MemoryEvent.profileRefreshOnGc}-$refreshOnGc',
            );
          },
        );
      },
    );
  }
}

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic =
      analytics_constants.MemoryEvent.profileHelp;

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
