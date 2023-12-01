// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_controller.dart';
import '../../../../shared/table/table_data.dart';
import '../../../vm_developer/vm_service_private_extensions.dart';
import '../../shared/heap/class_filter.dart';
import '../../shared/primitives/simple_elements.dart';
import '../../shared/widgets/class_filter.dart';
import '../../shared/widgets/shared_memory_widgets.dart';
import 'instances.dart';
import 'model.dart';
import 'profile_pane_controller.dart';

// TODO(bkonyi): ensure data displayed in this view is included in the full
// memory page export and is serializable/deserializable.

/// The default width for columns containing *mostly* numeric data (e.g.,
/// instances, memory).
const _defaultNumberFieldWidth = 90.0;

class _FieldClassNameColumn extends ColumnData<ProfileRecord>
    implements
        ColumnRenderer<ProfileRecord>,
        ColumnHeaderRenderer<ProfileRecord> {
  _FieldClassNameColumn(this.classFilterData)
      : super(
          'Class',
          fixedWidthPx: scaleByFontFactor(200),
        );

  @override
  String? getValue(ProfileRecord dataObject) => dataObject.heapClass.className;

  // We are removing the tooltip, because it is provided by [HeapClassView].
  @override
  String getTooltip(ProfileRecord dataObject) => '';

  @override
  bool get supportsSorting => true;

  final ClassFilterData classFilterData;

  @override
  Widget? build(
    BuildContext context,
    ProfileRecord data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    if (data.isTotal) return null;

    return HeapClassView(
      theClass: data.heapClass,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvent.diffClassSingleCopy,
      rootPackage: serviceConnection.serviceManager.rootInfoNow().package,
    );
  }

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: defaultHeaderRenderer()),
        ClassFilterButton(classFilterData),
      ],
    );
  }
}

/// For more information on the Dart GC implementation, see:
/// https://medium.com/flutter/flutter-dont-fear-the-garbage-collector-d69b3ff1ca30
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

class _FieldInstanceCountColumn extends ColumnData<ProfileRecord>
    implements ColumnRenderer<ProfileRecord> {
  _FieldInstanceCountColumn({required this.heap})
      : super(
          'Instances',
          titleTooltip: 'The number of instances of the class in the heap',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  final HeapGeneration heap;

  @override
  int? getValue(ProfileRecord dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpaceInstances;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpaceInstances;
      case HeapGeneration.total:
        return dataObject.totalInstances;
    }
  }

  @override
  bool get numeric => true;

  @override
  Widget? build(
    BuildContext context,
    ProfileRecord data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return ProfileInstanceTableCell(
      data.heapClass,
      gac.MemoryAreas.profile,
      isSelected: isRowSelected,
      count: data.totalInstances ?? 0,
    );
  }
}

class _FieldExternalSizeColumn extends _FieldSizeColumn {
  _FieldExternalSizeColumn({required super.heap})
      : super._(
          title: 'External',
          titleTooltip:
              'Non-Dart heap allocated memory associated with a Dart object',
        );

  @override
  int? getValue(ProfileRecord dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpaceExternalSize;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpaceExternalSize;
      case HeapGeneration.total:
        return dataObject.totalExternalSize;
    }
  }
}

class _FieldDartHeapSizeColumn extends _FieldSizeColumn {
  _FieldDartHeapSizeColumn({required super.heap})
      : super._(
          title: 'Dart Heap',
          titleTooltip: SizeType.shallow.description,
        );

  @override
  int? getValue(ProfileRecord dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpaceDartHeapSize;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpaceDartHeapSize;
      case HeapGeneration.total:
        return dataObject.totalDartHeapSize;
    }
  }
}

class _FieldSizeColumn extends ColumnData<ProfileRecord> {
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

  final HeapGeneration heap;

  @override
  int? getValue(ProfileRecord dataObject) {
    switch (heap) {
      case HeapGeneration.newSpace:
        return dataObject.newSpaceSize;
      case HeapGeneration.oldSpace:
        return dataObject.oldSpaceSize;
      case HeapGeneration.total:
        return dataObject.totalSize;
    }
  }

  @override
  String getDisplayValue(ProfileRecord dataObject) =>
      prettyPrintBytes(
        getValue(dataObject),
        includeUnit: true,
        kbFractionDigits: 1,
      ) ??
      '';

  @override
  String getTooltip(ProfileRecord dataObject) => '${getValue(dataObject)} B';

  @override
  bool get numeric => true;
}

abstract class _GCHeapStatsColumn extends ColumnData<AdaptedProfile> {
  _GCHeapStatsColumn(
    super.title, {
    required this.generation,
    required super.fixedWidthPx,
    super.titleTooltip,
    super.alignment,
  });

  final HeapGeneration generation;

  GCStats getGCStats(AdaptedProfile profile) {
    switch (generation) {
      case HeapGeneration.newSpace:
        return profile.newSpaceGCStats;
      case HeapGeneration.oldSpace:
        return profile.oldSpaceGCStats;
      case HeapGeneration.total:
        return profile.totalGCStats;
    }
  }
}

class _GCHeapNameColumn extends ColumnData<AdaptedProfile> {
  _GCHeapNameColumn()
      : super(
          '',
          fixedWidthPx: scaleByFontFactor(200),
        );

  @override
  String? getValue(AdaptedProfile dataObject) {
    return 'GC Statistics';
  }
}

class _GCHeapUsageColumn extends _GCHeapStatsColumn {
  _GCHeapUsageColumn({required super.generation})
      : super(
          'Usage',
          titleTooltip: 'The current amount of memory allocated from the heap',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  @override
  int? getValue(AdaptedProfile dataObject) {
    return getGCStats(dataObject).usage;
  }

  @override
  String getDisplayValue(AdaptedProfile dataObject) {
    return prettyPrintBytes(getValue(dataObject), includeUnit: true)!;
  }

  @override
  bool get numeric => true;
}

class _GCHeapCapacityColumn extends _GCHeapStatsColumn {
  _GCHeapCapacityColumn({required super.generation})
      : super(
          'Capacity',
          titleTooltip:
              'The current size of the heap, including unallocated memory',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  @override
  int? getValue(AdaptedProfile dataObject) {
    return getGCStats(dataObject).capacity;
  }

  @override
  String getDisplayValue(AdaptedProfile dataObject) {
    return prettyPrintBytes(getValue(dataObject), includeUnit: true)!;
  }

  @override
  bool get numeric => true;
}

class _GCCountColumn extends _GCHeapStatsColumn {
  _GCCountColumn({required super.generation})
      : super(
          'Collections',
          titleTooltip: 'The number of garbage collections run on the heap',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  @override
  int? getValue(AdaptedProfile dataObject) {
    return getGCStats(dataObject).collections;
  }

  @override
  bool get numeric => true;
}

class _GCLatencyColumn extends _GCHeapStatsColumn {
  _GCLatencyColumn({required super.generation})
      : super(
          'Latency',
          titleTooltip:
              'The average time taken to perform a garbage collection on the heap (ms)',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(_defaultNumberFieldWidth),
        );

  @override
  double? getValue(AdaptedProfile dataObject) {
    final stats = getGCStats(dataObject);
    if (stats.averageCollectionTime.isNaN) {
      return 0;
    }
    return getGCStats(dataObject).averageCollectionTime;
  }

  @override
  String getDisplayValue(AdaptedProfile dataObject) {
    return durationText(
      Duration(
        milliseconds: getValue(dataObject)!.toInt(),
      ),
      fractionDigits: 2,
    );
  }

  @override
  bool get numeric => true;
}

class _GCStatsTable extends StatelessWidget {
  const _GCStatsTable({
    Key? key,
    required this.controller,
  }) : super(key: key);

  static final _columnGroup = [
    ColumnGroup.fromText(
      title: '',
      range: const Range(0, 1),
    ),
    ColumnGroup.fromText(
      title: HeapGeneration.total.toString(),
      range: const Range(1, 5),
    ),
    ColumnGroup.fromText(
      title: HeapGeneration.newSpace.toString(),
      range: const Range(5, 9),
    ),
    ColumnGroup.fromText(
      title: HeapGeneration.oldSpace.toString(),
      range: const Range(9, 13),
    ),
  ];

  static final _columns = [
    _GCHeapNameColumn(),
    for (final generation in [
      HeapGeneration.total,
      HeapGeneration.newSpace,
      HeapGeneration.oldSpace,
    ]) ...[
      _GCHeapUsageColumn(generation: generation),
      _GCHeapCapacityColumn(generation: generation),
      _GCCountColumn(
        generation: generation,
      ),
      _GCLatencyColumn(
        generation: generation,
      ),
    ],
  ];

  final ProfilePaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdaptedProfile?>(
      valueListenable: controller.currentAllocationProfile,
      builder: (context, profile, _) {
        if (profile == null) {
          return const CenteredCircularProgressIndicator();
        }
        return OutlineDecoration.onlyTop(
          child: FlatTable<AdaptedProfile>(
            keyFactory: (element) => Key(element.hashCode.toString()),
            data: [profile],
            dataKey: 'gc-stats',
            columnGroups: _columnGroup,
            columns: _columns,
            defaultSortColumn: _columns.first,
            defaultSortDirection: SortDirection.ascending,
          ),
        );
      },
    );
  }
}

/// Displays data from an [AllocationProfile] in a tabular format, with support
/// for refreshing the data on a garbage collection (GC) event and exporting
/// [AllocationProfile]'s to a CSV formatted file.
class AllocationProfileTableView extends StatefulWidget {
  const AllocationProfileTableView({super.key, required this.controller});

  @override
  State<AllocationProfileTableView> createState() =>
      AllocationProfileTableViewState();

  final ProfilePaneController controller;
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
        Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: _AllocationProfileTableControls(
            allocationProfileController: widget.controller,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: preferences.vmDeveloperModeEnabled,
          builder: (context, vmDeveloperModeEnabled, _) {
            if (!vmDeveloperModeEnabled) return const SizedBox.shrink();
            return Column(
              children: [
                SizedBox(
                  // _GCStatsTable is a table with two header rows (column groups
                  // and columns) and one data row. We add a slight padding to
                  // ensure the underlying scrollable area has enough space to not
                  // display a scroll bar.
                  height: defaultRowHeight + areaPaneHeaderHeight * 2 + 1,
                  child: _GCStatsTable(
                    controller: widget.controller,
                  ),
                ),
                const ThickDivider(),
              ],
            );
          },
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
  _AllocationProfileTable({
    Key? key,
    required this.controller,
  }) : super(key: key);

  /// List of columns displayed in VM developer mode state.
  static final _vmModeColumnGroups = [
    ColumnGroup.fromText(
      title: '',
      range: const Range(0, 1),
    ),
    ColumnGroup.fromText(
      title: HeapGeneration.total.toString(),
      range: const Range(1, 5),
    ),
    ColumnGroup.fromText(
      title: HeapGeneration.newSpace.toString(),
      range: const Range(5, 9),
    ),
    ColumnGroup.fromText(
      title: HeapGeneration.oldSpace.toString(),
      range: const Range(9, 13),
    ),
  ];

  static final _fieldSizeColumn = _FieldSizeColumn(
    heap: HeapGeneration.total,
  );

  late final List<ColumnData<ProfileRecord>> _columns = [
    _FieldClassNameColumn(
      ClassFilterData(
        filter: controller.classFilter,
        onChanged: controller.setFilter,
      ),
    ),
    _FieldInstanceCountColumn(heap: HeapGeneration.total),
    _fieldSizeColumn,
    _FieldDartHeapSizeColumn(heap: HeapGeneration.total),
  ];

  late final _vmDeveloperModeColumns = [
    _FieldExternalSizeColumn(heap: HeapGeneration.total),
    _FieldInstanceCountColumn(heap: HeapGeneration.newSpace),
    _FieldSizeColumn(heap: HeapGeneration.newSpace),
    _FieldDartHeapSizeColumn(heap: HeapGeneration.newSpace),
    _FieldExternalSizeColumn(heap: HeapGeneration.newSpace),
    _FieldInstanceCountColumn(heap: HeapGeneration.oldSpace),
    _FieldSizeColumn(heap: HeapGeneration.oldSpace),
    _FieldDartHeapSizeColumn(heap: HeapGeneration.oldSpace),
    _FieldExternalSizeColumn(heap: HeapGeneration.oldSpace),
  ];

  final ProfilePaneController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdaptedProfile?>(
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
            return FlatTable<ProfileRecord>(
              keyFactory: (element) => Key(element.heapClass.fullName),
              data: profile.records,
              dataKey: 'allocation-profile',
              columnGroups: vmDeveloperModeEnabled
                  ? _AllocationProfileTable._vmModeColumnGroups
                  : null,
              columns: [
                ..._columns,
                if (vmDeveloperModeEnabled) ..._vmDeveloperModeColumns,
              ],
              defaultSortColumn: _AllocationProfileTable._fieldSizeColumn,
              defaultSortDirection: SortDirection.descending,
              pinBehavior: FlatTablePinBehavior.pinOriginalToTop,
              includeColumnGroupHeaders: false,
              selectionNotifier: controller.selection,
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

  final ProfilePaneController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ExportAllocationProfileButton(
          allocationProfileController: allocationProfileController,
        ),
        const SizedBox(width: denseSpacing),
        RefreshButton(
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvent.profileRefreshManual,
          onPressed: allocationProfileController.refresh,
        ),
        const SizedBox(width: denseSpacing),
        _RefreshOnGCToggleButton(
          allocationProfileController: allocationProfileController,
        ),
        const SizedBox(width: denseSpacing),
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

  final ProfilePaneController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdaptedProfile?>(
      valueListenable: allocationProfileController.currentAllocationProfile,
      builder: (context, currentAllocationProfile, _) {
        return ToCsvButton(
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvent.profileDownloadCsv,
          minScreenWidthForTextBeforeScaling: memoryControlsMinVerboseWidth,
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

  final ProfilePaneController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: allocationProfileController.refreshOnGc,
      builder: (context, refreshOnGc, _) {
        return DevToolsToggleButton(
          message: 'Auto-refresh on garbage collection',
          label: 'Refresh on GC',
          icon: Icons.autorenew_outlined,
          isSelected: refreshOnGc,
          onPressed: () {
            allocationProfileController.toggleRefreshOnGc();
            ga.select(
              gac.memory,
              '${gac.MemoryEvent.profileRefreshOnGc}-$refreshOnGc',
            );
          },
        );
      },
    );
  }
}

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = gac.MemoryEvent.profileHelp;

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: gac.memory,
      gaSelection: gac.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Allocation Profile Help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('The allocation profile tab displays information about\n'
              'allocated objects in the Dart heap of the selected\n'
              'isolate.'),
          const SizedBox(height: denseSpacing),
          const ClassTypeLegend(),
          MoreInfoLink(
            url: DocLinks.profile.value,
            gaScreenName: '',
            gaSelectedItemDescription:
                gac.topicDocumentationLink(_documentationTopic),
          ),
        ],
      ),
    );
  }
}
