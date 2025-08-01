// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/globals.dart';
import '../../../../shared/memory/gc_stats.dart';
import '../../../../shared/primitives/byte_utils.dart';
import '../../../../shared/primitives/simple_items.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_controller.dart';
import '../../../../shared/table/table_data.dart';
import '../../../../shared/ui/common_widgets.dart';
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
const _defaultNumberFieldWidth = 80.0;

class _FieldClassNameColumn extends ColumnData<ProfileRecord>
    implements
        ColumnRenderer<ProfileRecord>,
        ColumnHeaderRenderer<ProfileRecord> {
  const _FieldClassNameColumn(this.classFilterData)
    : super('Class', fixedWidthPx: 200);

  @override
  String? getValue(ProfileRecord dataObject) => dataObject.heapClass.className;

  // We are removing the tooltip, because it is provided by [HeapClassView].
  @override
  String getTooltip(ProfileRecord dataObject) => '';

  final ClassFilterData classFilterData;

  @override
  Widget? build(
    BuildContext context,
    ProfileRecord data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
  }) {
    if (data.isTotal) return null;

    return HeapClassView(
      theClass: data.heapClass,
      showCopyButton: isRowSelected,
      copyGaItem: gac.MemoryEvents.diffClassSingleCopy.name,
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
  const _FieldInstanceCountColumn({required this.heap})
    : super(
        'Instances',
        titleTooltip: 'The number of instances of the class in the heap',
        alignment: ColumnAlignment.right,
        fixedWidthPx: _defaultNumberFieldWidth,
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
  const _FieldExternalSizeColumn({required super.heap})
    : super(
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
    : super(title: 'Dart Heap', titleTooltip: SizeType.shallow.description);

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
  const _FieldSizeColumn({
    String title = 'Total Size',
    String titleTooltip =
        "The sum of the type's total shallow memory "
        'consumption in the Dart heap and associated external (e.g., '
        'non-Dart heap) allocations',
    required this.heap,
  }) : super(
         title,
         titleTooltip: titleTooltip,
         alignment: ColumnAlignment.right,
         fixedWidthPx: _defaultNumberFieldWidth,
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
      prettyPrintBytes(getValue(dataObject), includeUnit: true) ?? '';

  @override
  String getTooltip(ProfileRecord dataObject) => '${getValue(dataObject)} B';

  @override
  bool get numeric => true;
}

abstract class _GCHeapStatsColumn extends ColumnData<AdaptedProfile> {
  const _GCHeapStatsColumn(
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
  const _GCHeapNameColumn() : super('', fixedWidthPx: 200);

  @override
  String? getValue(AdaptedProfile dataObject) {
    return 'GC Statistics';
  }

  @override
  bool get supportsSorting => false;
}

class _GCHeapUsageColumn extends _GCHeapStatsColumn {
  _GCHeapUsageColumn({required super.generation})
    : super(
        'Usage',
        titleTooltip: 'The current amount of memory allocated from the heap',
        alignment: ColumnAlignment.right,
        fixedWidthPx: _defaultNumberFieldWidth,
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
        fixedWidthPx: _defaultNumberFieldWidth,
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
        fixedWidthPx: _defaultNumberFieldWidth,
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
        fixedWidthPx: _defaultNumberFieldWidth,
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
      Duration(milliseconds: getValue(dataObject)!.toInt()),
      fractionDigits: 2,
    );
  }

  @override
  bool get numeric => true;
}

class _GCStatsTable extends StatelessWidget {
  const _GCStatsTable({required this.controller});

  static final _columnGroup = [
    ColumnGroup.fromText(title: '', range: const Range(0, 1)),
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
    const _GCHeapNameColumn(),
    for (final generation in [
      HeapGeneration.total,
      HeapGeneration.newSpace,
      HeapGeneration.oldSpace,
    ]) ...[
      _GCHeapUsageColumn(generation: generation),
      _GCHeapCapacityColumn(generation: generation),
      _GCCountColumn(generation: generation),
      _GCLatencyColumn(generation: generation),
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
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  void didUpdateWidget(AllocationProfileTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: _AllocationProfileTableControls(controller: widget.controller),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: preferences.advancedDeveloperModeEnabled,
          builder: (context, advancedDeveloperModeEnabled, _) {
            if (!advancedDeveloperModeEnabled) return const SizedBox.shrink();
            return Column(
              children: [
                SizedBox(
                  // _GCStatsTable is a table with two header rows (column groups
                  // and columns) and one data row. We add a slight padding to
                  // ensure the underlying scrollable area has enough space to not
                  // display a scroll bar.
                  height: defaultRowHeight + defaultHeaderHeight * 2 + 1,
                  child: _GCStatsTable(controller: widget.controller),
                ),
                const ThickDivider(),
              ],
            );
          },
        ),
        Expanded(child: _AllocationProfileTable(controller: widget.controller)),
      ],
    );
  }
}

class _AllocationProfileTable extends StatelessWidget {
  _AllocationProfileTable({required this.controller});

  /// List of columns displayed in advanced developer mode state.
  static final _vmModeColumnGroups = [
    ColumnGroup.fromText(title: '', range: const Range(0, 1)),
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

  static const _fieldSizeColumn = _FieldSizeColumn(heap: HeapGeneration.total);

  late final _columns = <ColumnData<ProfileRecord>>[
    _FieldClassNameColumn(
      ClassFilterData(
        filter: controller.classFilter,
        onChanged: controller.setFilter,
        rootPackage: controller.rootPackage,
      ),
    ),
    const _FieldInstanceCountColumn(heap: HeapGeneration.total),
    _fieldSizeColumn,
    _FieldDartHeapSizeColumn(heap: HeapGeneration.total),
  ];

  late final _advancedDeveloperModeColumns = [
    const _FieldExternalSizeColumn(heap: HeapGeneration.total),
    const _FieldInstanceCountColumn(heap: HeapGeneration.newSpace),
    const _FieldSizeColumn(heap: HeapGeneration.newSpace),
    _FieldDartHeapSizeColumn(heap: HeapGeneration.newSpace),
    const _FieldExternalSizeColumn(heap: HeapGeneration.newSpace),
    const _FieldInstanceCountColumn(heap: HeapGeneration.oldSpace),
    const _FieldSizeColumn(heap: HeapGeneration.oldSpace),
    _FieldDartHeapSizeColumn(heap: HeapGeneration.oldSpace),
    const _FieldExternalSizeColumn(heap: HeapGeneration.oldSpace),
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
          valueListenable: preferences.advancedDeveloperModeEnabled,
          builder: (context, advancedDeveloperModeEnabled, _) {
            return FlatTable<ProfileRecord>(
              keyFactory: (element) => Key(element.heapClass.fullName),
              data: profile.records,
              dataKey: 'allocation-profile',
              columnGroups: advancedDeveloperModeEnabled
                  ? _AllocationProfileTable._vmModeColumnGroups
                  : null,
              columns: [
                ..._columns,
                if (advancedDeveloperModeEnabled)
                  ..._advancedDeveloperModeColumns,
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
  const _AllocationProfileTableControls({required this.controller});

  final ProfilePaneController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ExportAllocationProfileButton(allocationProfileController: controller),
        if (!offlineDataController.showingOfflineData.value) ...[
          const SizedBox(width: denseSpacing),
          RefreshButton(
            gaScreen: gac.memory,
            gaSelection: gac.MemoryEvents.profileRefreshManual.name,
            onPressed: controller.refresh,
          ),
          const SizedBox(width: denseSpacing),
          _RefreshOnGCToggleButton(allocationProfileController: controller),
        ],
        const SizedBox(width: denseSpacing),
        const _ProfileHelpLink(),
      ],
    );
  }
}

class _ExportAllocationProfileButton extends StatelessWidget {
  const _ExportAllocationProfileButton({
    required this.allocationProfileController,
  });

  final ProfilePaneController allocationProfileController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdaptedProfile?>(
      valueListenable: allocationProfileController.currentAllocationProfile,
      builder: (context, currentAllocationProfile, _) {
        return DownloadButton(
          gaScreen: gac.memory,
          gaSelection: gac.MemoryEvents.profileDownloadCsv.name,
          minScreenWidthForText: memoryControlsMinVerboseWidth,
          tooltip: 'Download allocation profile data in CSV format',
          label: 'CSV',
          onPressed: currentAllocationProfile == null
              ? null
              : () => allocationProfileController.downloadMemoryTableCsv(
                  currentAllocationProfile,
                ),
        );
      },
    );
  }
}

class _RefreshOnGCToggleButton extends StatelessWidget {
  const _RefreshOnGCToggleButton({required this.allocationProfileController});

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
              '${gac.MemoryEvents.profileRefreshOnGc.name}-$refreshOnGc',
            );
          },
        );
      },
    );
  }
}

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink();

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: gac.memory,
      gaSelection: gac.topicDocumentationButton(
        gac.MemoryEvents.profileHelp.name,
      ),
      dialogTitle: 'Memory Allocation Profile Help',
      actions: [
        MoreInfoLink(
          url: DocLinks.profile.value,
          gaScreenName: '',
          gaSelectedItemDescription: gac.topicDocumentationLink(
            gac.MemoryEvents.profileHelp.name,
          ),
        ),
      ],
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'The allocation profile tab displays information about\n'
            'allocated objects in the Dart heap of the selected\n'
            'isolate.',
          ),
          SizedBox(height: denseSpacing),
          ClassTypeLegend(),
        ],
      ),
    );
  }
}
