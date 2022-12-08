// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/split.dart';
import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../../../shared/theme.dart';
import '../../profiler/cpu_profiler.dart';
import '../vm_developer_common_widgets.dart';
import '../vm_developer_tools_screen.dart';
import '../vm_service_private_extensions.dart';
import 'isolate_statistics_view_controller.dart';

/// Displays general information about the state of the currently selected
/// isolate.
class IsolateStatisticsView extends VMDeveloperView {
  const IsolateStatisticsView()
      : super(
          id,
          title: 'Isolates',
          icon: Icons.bar_chart,
        );
  static const id = 'isolate-statistics';

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) => IsolateStatisticsViewBody();
}

class IsolateStatisticsViewBody extends StatelessWidget {
  final controller = IsolateStatisticsViewController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.refreshing,
      builder: (context, refreshing, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RefreshButton(
              onPressed: controller.refresh,
            ),
            const SizedBox(height: denseRowSpacing),
            Flexible(
              child: Column(
                children: [
                  Flexible(
                    child: _buildTopRow(),
                  ),
                  Flexible(
                    child: IsolatePortsWidget(
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        Flexible(
          child: Column(
            children: [
              Expanded(
                child: GeneralIsolateStatisticsWidget(
                  controller: controller,
                ),
              ),
              Expanded(
                child: IsolateMemoryStatisticsWidget(
                  controller: controller,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: TagStatisticsWidget(
            controller: controller,
          ),
        ),
        Flexible(
          child: ServiceExtensionsWidget(
            controller: controller,
          ),
        ),
      ],
    );
  }
}

/// Displays general information about the current isolate, including:
///   - Isolate debug name
///   - Start time and uptime
///   - Root library
///   - Isolate ID
class GeneralIsolateStatisticsWidget extends StatelessWidget {
  const GeneralIsolateStatisticsWidget({required this.controller});

  final IsolateStatisticsViewController controller;

  String? _startTime(Isolate? isolate) {
    if (isolate == null) {
      return null;
    }
    final startedAtFormatter = DateFormat.yMMMMd().add_jms();
    return startedAtFormatter.format(
      DateTime.fromMillisecondsSinceEpoch(
        isolate.startTime!,
      ).toLocal(),
    );
  }

  String? _uptime(Isolate? isolate) {
    if (isolate == null) {
      return null;
    }
    final uptimeFormatter = DateFormat.Hms();
    return uptimeFormatter.format(
      DateTime.now()
          .subtract(
            Duration(milliseconds: isolate.startTime!),
          )
          .toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isolate = controller.isolate;
    return OutlineDecoration(
      showRight: false,
      showBottom: false,
      child: VMInfoCard(
        title: 'General',
        rowKeyValues: [
          selectableTextBuilderMapEntry('Name', isolate?.name),
          selectableTextBuilderMapEntry('Started at', _startTime(isolate)),
          selectableTextBuilderMapEntry('Uptime', _uptime(isolate)),
          selectableTextBuilderMapEntry('Root Library', isolate?.rootLib?.uri),
          selectableTextBuilderMapEntry('ID', isolate?.id),
        ],
      ),
    );
  }
}

/// Displays memory statistics for the isolate, including:
///   - Total Dart heap size
///   - New + Old space capacity and usage
class IsolateMemoryStatisticsWidget extends StatelessWidget {
  const IsolateMemoryStatisticsWidget({required this.controller});

  final IsolateStatisticsViewController controller;

  String _buildMemoryString(num? usage, num? capacity) {
    if (usage == null || capacity == null) {
      return '--';
    }
    return '${prettyPrintBytes(usage, includeUnit: true)}'
        ' of ${prettyPrintBytes(capacity, includeUnit: true)}';
  }

  @override
  Widget build(BuildContext context) {
    final isolate = controller.isolate;
    return OutlineDecoration(
      showRight: false,
      showBottom: false,
      child: VMInfoCard(
        title: 'Memory',
        rowKeyValues: [
          selectableTextBuilderMapEntry(
            'Dart Heap',
            _buildMemoryString(
              isolate?.dartHeapSize,
              isolate?.dartHeapCapacity,
            ),
          ),
          selectableTextBuilderMapEntry(
            'New Space',
            _buildMemoryString(
              isolate?.newSpaceUsage,
              isolate?.newSpaceUsage,
            ),
          ),
          selectableTextBuilderMapEntry(
            'Old Space',
            _buildMemoryString(
              isolate?.oldSpaceUsage,
              isolate?.oldSpaceCapacity,
            ),
          ),
        ],
      ),
    );
  }
}

/// A table which displays the amount of time the VM is performing certain
/// tagged tasks.
class TagStatisticsWidget extends StatelessWidget {
  const TagStatisticsWidget({required this.controller});

  static final _name = _TagColumn();
  static final _percentage = _PercentageColumn();
  static final List<ColumnData<VMTag>> columns = [_name, _percentage];

  final IsolateStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      showBottom: false,
      child: VMInfoCard(
        title: 'Execution Time',
        table: Flexible(
          child: controller.cpuProfilerController.profilerEnabled
              ? FlatTable<VMTag>(
                  keyFactory: (VMTag tag) => ValueKey<String>(tag.name),
                  data: controller.tags,
                  dataKey: 'tag-statistics',
                  columns: columns,
                  defaultSortColumn: _percentage,
                  defaultSortDirection: SortDirection.descending,
                )
              : CpuProfilerDisabled(
                  controller.cpuProfilerController,
                ),
        ),
      ),
    );
  }
}

class _TagColumn extends ColumnData<VMTag> {
  _TagColumn() : super.wide('Tag');

  @override
  String getValue(VMTag dataObject) => dataObject.name;
}

class _PercentageColumn extends ColumnData<VMTag> {
  _PercentageColumn()
      : super.wide('Percentage', alignment: ColumnAlignment.right);

  @override
  double getValue(VMTag dataObject) => dataObject.percentage;

  @override
  String getDisplayValue(VMTag dataObject) => percent2(dataObject.percentage);
}

class _PortIDColumn extends ColumnData<InstanceRef> {
  _PortIDColumn() : super.wide('ID');

  @override
  String getValue(InstanceRef port) => port.portId.toString();
}

class _PortNameColumn extends ColumnData<InstanceRef> {
  _PortNameColumn() : super.wide('Name');

  @override
  String getValue(InstanceRef port) {
    final debugName = port.debugName!;
    return debugName.isEmpty ? 'N/A' : debugName;
  }
}

class _StackTraceViewerFrameColumn extends ColumnData<String> {
  _StackTraceViewerFrameColumn() : super.wide('Frame');

  @override
  String getValue(String frame) => frame;

  @override
  int compare(String f1, String f2) {
    return _frameNumber(f1).compareTo(_frameNumber(f2));
  }

  int _frameNumber(String frame) {
    return int.parse(frame.split(' ').first.substring(1));
  }
}

// TODO(bkonyi): merge with debugger stack trace viewer.
/// A simple table to display a stack trace, sorted by frame number.
class StackTraceViewerWidget extends StatelessWidget {
  StackTraceViewerWidget({required this.stackTrace});

  final InstanceRef? stackTrace;
  final frame = _StackTraceViewerFrameColumn();

  @override
  Widget build(BuildContext context) {
    final List<String>? lines = stackTrace?.allocationLocation?.valueAsString
        ?.split('\n')
        .where((e) => e.isNotEmpty)
        .toList();
    return VMInfoList(
      title: 'Allocation Location',
      table: lines == null
          ? const Expanded(
              child: Center(
                child: Text('No port selected'),
              ),
            )
          : Flexible(
              child: FlatTable<String>(
                keyFactory: (String s) => ValueKey<String>(s),
                data: lines,
                dataKey: 'stack-trace-viewer',
                columns: [
                  frame,
                ],
                defaultSortColumn: frame,
                defaultSortDirection: SortDirection.ascending,
              ),
            ),
    );
  }
}

/// Displays information about open ReceivePorts, including:
///   - Debug name (if provided, but all instances from the core libraries
///     will report this)
///   - Internal port ID
///   - Allocation location stack trace
class IsolatePortsWidget extends StatefulWidget {
  const IsolatePortsWidget({required this.controller});

  final IsolateStatisticsViewController controller;

  @override
  _IsolatePortsWidgetState createState() => _IsolatePortsWidgetState();
}

class _IsolatePortsWidgetState extends State<IsolatePortsWidget> {
  static final _id = _PortIDColumn();
  static final _name = _PortNameColumn();
  static final List<ColumnData<InstanceRef>> _columns = [
    _name,
    _id,
  ];

  final selectedPort = ValueNotifier<InstanceRef?>(null);

  @override
  Widget build(BuildContext context) {
    final ports = widget.controller.ports;
    return OutlineDecoration(
      child: Split(
        axis: Axis.horizontal,
        initialFractions: const [
          0.3,
          0.7,
        ],
        children: [
          OutlineDecoration.onlyRight(
            child: Column(
              children: [
                AreaPaneHeader(
                  needsTopBorder: false,
                  title: Text(
                    'Open Ports (${ports.length})',
                  ),
                ),
                Flexible(
                  child: FlatTable<InstanceRef?>(
                    keyFactory: (InstanceRef? port) =>
                        ValueKey<String>(port!.debugName!),
                    data: ports,
                    dataKey: 'isolate-ports',
                    columns: _columns,
                    defaultSortColumn: _id,
                    defaultSortDirection: SortDirection.ascending,
                    selectionNotifier: selectedPort,
                  ),
                ),
              ],
            ),
          ),
          OutlineDecoration.onlyLeft(
            child: StackTraceViewerWidget(
              stackTrace: selectedPort.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceExtensionNameColumn extends ColumnData<String> {
  _ServiceExtensionNameColumn() : super.wide('Name');

  @override
  String getValue(String s) => s;
}

/// A table displaying the list of service extensions registered with an
/// isolate.
class ServiceExtensionsWidget extends StatelessWidget {
  const ServiceExtensionsWidget({required this.controller});

  static final _name = _ServiceExtensionNameColumn();

  static final List<ColumnData<String>> _columns = [
    _name,
  ];

  final IsolateStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    final extensions = controller.isolate?.extensionRPCs ?? [];
    return OutlineDecoration(
      showBottom: false,
      showLeft: false,
      child: VMInfoCard(
        title: 'Service Extensions (${extensions.length})',
        table: Flexible(
          child: FlatTable<String>(
            keyFactory: (String extension) => ValueKey<String>(extension),
            data: extensions,
            dataKey: 'registered-service-extensions',
            columns: _columns,
            defaultSortColumn: _name,
            defaultSortDirection: SortDirection.ascending,
          ),
        ),
      ),
    );
  }
}
