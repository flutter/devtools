// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../profiler/cpu_profiler.dart';
import '../split.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'isolate_statistics_view_controller.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_developer_tools_screen.dart';
import 'vm_service_private_extensions.dart';

/// Displays general information about the state of the currently selected
/// isolate.
class IsolateStatisticsView extends VMDeveloperView {
  const IsolateStatisticsView()
      : super(
          id,
          title: 'Isolates',
          icon: Icons.bar_chart_sharp,
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
          children: [
            Row(
              children: [
                RefreshButton(
                  onPressed: controller.refresh,
                ),
              ],
            ),
            Flexible(
              child: Column(
                children: [
                  Flexible(
                    child: _buildTopRow(),
                  ),
                  Flexible(
                    child: _buildBottomRow(),
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
          child: GeneralIsolateStatisticsWidget(
            controller: controller,
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

  Widget _buildBottomRow() {
    return Row(
      children: [
        Flexible(
          child: IsolateMemoryStatisticsWidget(
            controller: controller,
          ),
        ),
        Flexible(
          flex: 2,
          child: IsolatePortsWidget(
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
  const GeneralIsolateStatisticsWidget({@required this.controller});

  final IsolateStatisticsViewController controller;

  String _startTime(Isolate isolate) {
    if (isolate == null) {
      return null;
    }
    final startedAtFormatter = DateFormat.yMMMMd().add_jms();
    return startedAtFormatter.format(
      DateTime.fromMillisecondsSinceEpoch(
        isolate.startTime,
      ).toLocal(),
    );
  }

  String _uptime(Isolate isolate) {
    if (isolate == null) {
      return null;
    }
    final uptimeFormatter = DateFormat.Hms();
    return uptimeFormatter.format(
      DateTime.now()
          .subtract(
            Duration(milliseconds: isolate.startTime),
          )
          .toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isolate = controller.isolate;
    return VMInfoCard(
      title: 'General',
      rowKeyValues: [
        MapEntry('Name', isolate?.name),
        MapEntry('Started at', _startTime(isolate)),
        MapEntry('Uptime', _uptime(isolate)),
        MapEntry('Root Library', isolate?.rootLib?.uri),
        MapEntry('ID', isolate?.id),
      ],
    );
  }
}

/// Displays memory statistics for the isolate, including:
///   - Total Dart heap size
///   - New + Old space capacity and usage
///   - Handle counts (zone + scoped)
///   - Per-thread zone memory usage
class IsolateMemoryStatisticsWidget extends StatelessWidget {
  const IsolateMemoryStatisticsWidget({@required this.controller});

  final IsolateStatisticsViewController controller;

  String _buildMemoryString(num usage, num capacity) {
    if (usage == null || capacity == null) {
      return '--';
    }
    return '${prettyPrintBytes(usage, includeUnit: true)}'
        ' of ${prettyPrintBytes(capacity, includeUnit: true)}';
  }

  @override
  Widget build(BuildContext context) {
    final isolate = controller.isolate;
    return Column(
      children: [
        Flexible(
          child: VMInfoCard(
            title: 'Memory',
            rowKeyValues: [
              MapEntry(
                'Dart Heap',
                _buildMemoryString(
                  isolate?.dartHeapSize,
                  isolate?.dartHeapCapacity,
                ),
              ),
              MapEntry(
                'New Space',
                _buildMemoryString(
                  isolate?.newSpaceUsage,
                  isolate?.newSpaceUsage,
                ),
              ),
              MapEntry(
                'Old Space',
                _buildMemoryString(
                  isolate?.oldSpaceUsage,
                  isolate?.oldSpaceCapacity,
                ),
              ),
              MapEntry(
                'Max Zone Capacity',
                prettyPrintBytes(
                  controller.zoneCapacityHighWatermark,
                  includeUnit: true,
                ),
              ),
              MapEntry('# of Zone Handles', isolate?.zoneHandleCount),
              MapEntry('# of Scoped Handles', isolate?.scopedHandleCount),
            ],
            table: Flexible(
              child: ThreadMemoryTable(
                controller: controller,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A table which displays the amount of time the VM is performing certain
/// tagged tasks.
class TagStatisticsWidget extends StatelessWidget {
  TagStatisticsWidget({@required this.controller});

  final name = _TagColumn();
  final percentage = _PercentageColumn();

  List<ColumnData<VMTag>> get columns => [name, percentage];
  final IsolateStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    return VMInfoCard(
      title: 'Execution Time',
      table: Flexible(
        child: controller.cpuProfilerController.profilerEnabled
            ? FlatTable<VMTag>(
                columns: columns,
                data: controller.tags,
                keyFactory: (VMTag tag) => ValueKey<String>(tag.name),
                sortColumn: percentage,
                sortDirection: SortDirection.descending,
                onItemSelected: (_) => null,
              )
            : CpuProfilerDisabled(
                controller.cpuProfilerController,
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

/// Displays a table of threads associated with a given isolate with the
/// following information:
///   - Thread kind (e.g., mutator, background compiler, etc.)
///   - Maximum zone capacity (aka "high watermark")
///   - Current zone capacity
class ThreadMemoryTable extends StatelessWidget {
  ThreadMemoryTable({@required this.controller});

  final id = _IDColumn();
  final kind = _KindColumn();
  final watermark = _HighWatermarkColumn();
  final capacity = _ZoneCapacityColumn();

  List<ColumnData<Thread>> get columns => [
        id,
        kind,
        watermark,
        capacity,
      ];
  final IsolateStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    final threads = controller.isolate?.threads ?? [];
    return Column(
      children: [
        areaPaneHeader(context, title: 'Threads (${threads.length})'),
        Expanded(
          child: FlatTable<Thread>(
            columns: columns,
            data: threads,
            keyFactory: (Thread thread) => ValueKey<String>(thread.id),
            sortColumn: id,
            sortDirection: SortDirection.ascending,
            onItemSelected: (_) => null,
          ),
        ),
      ],
    );
  }
}

class _IDColumn extends ColumnData<Thread> {
  _IDColumn() : super.wide('ID');

  @override
  String getValue(Thread thread) => thread.id;
}

class _KindColumn extends ColumnData<Thread> {
  _KindColumn() : super.wide('Kind');

  @override
  String getValue(Thread thread) => thread.kind;
}

class _HighWatermarkColumn extends ColumnData<Thread> {
  _HighWatermarkColumn() : super.wide('Max Zone Capacity');

  @override
  int getValue(Thread thread) => thread.zoneHighWatermark;

  @override
  String getDisplayValue(Thread thread) => prettyPrintBytes(
        thread.zoneHighWatermark,
        includeUnit: true,
      );
}

class _ZoneCapacityColumn extends ColumnData<Thread> {
  _ZoneCapacityColumn() : super.wide('Current Zone Capacity');

  @override
  int getValue(Thread thread) => thread.zoneCapacity;

  @override
  String getDisplayValue(Thread thread) => prettyPrintBytes(
        thread.zoneCapacity,
        includeUnit: true,
      );
}

class _PortIDColumn extends ColumnData<InstanceRef> {
  _PortIDColumn() : super.wide('ID');

  @override
  String getValue(InstanceRef port) => port.portId.toString();
}

class _PortNameColumn extends ColumnData<InstanceRef> {
  _PortNameColumn() : super.wide('Name');

  @override
  String getValue(InstanceRef port) =>
      port.debugName.isEmpty ? 'N/A' : port.debugName;
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
  StackTraceViewerWidget({@required this.stackTrace});

  final InstanceRef stackTrace;
  final frame = _StackTraceViewerFrameColumn();

  @override
  Widget build(BuildContext context) {
    final List<String> lines = stackTrace?.allocationLocation?.valueAsString
        ?.split('\n')
        ?.where((e) => e.isNotEmpty)
        ?.toList();
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
                columns: [
                  frame,
                ],
                data: lines,
                keyFactory: (String s) => ValueKey<String>(s),
                onItemSelected: (_) => null,
                sortColumn: frame,
                sortDirection: SortDirection.ascending,
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
  const IsolatePortsWidget({@required this.controller});

  final IsolateStatisticsViewController controller;

  @override
  _IsolatePortsWidgetState createState() => _IsolatePortsWidgetState();
}

class _IsolatePortsWidgetState extends State<IsolatePortsWidget> {
  final id = _PortIDColumn();
  final name = _PortNameColumn();

  final selectedPort = ValueNotifier<InstanceRef>(null);

  List<ColumnData<InstanceRef>> get columns => [
        name,
        id,
      ];

  @override
  Widget build(BuildContext context) {
    final ports = widget.controller.ports;
    return Column(
      children: [
        Flexible(
          child: VMInfoCard(
            title: 'Open Ports (${ports.length})',
            table: Flexible(
              child: Split(
                axis: Axis.horizontal,
                children: [
                  FlatTable<InstanceRef>(
                    columns: columns,
                    data: ports,
                    keyFactory: (InstanceRef port) =>
                        ValueKey<String>(port.debugName),
                    sortColumn: id,
                    sortDirection: SortDirection.ascending,
                    selectionNotifier: selectedPort,
                    onItemSelected: (InstanceRef port) => setState(
                      () {
                        if (port == selectedPort.value) {
                          selectedPort.value = null;
                        } else {
                          selectedPort.value = port;
                        }
                      },
                    ),
                  ),
                  StackTraceViewerWidget(
                    stackTrace: selectedPort.value,
                  ),
                ],
                initialFractions: const [
                  0.3,
                  0.7,
                ],
              ),
            ),
          ),
        ),
      ],
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
  ServiceExtensionsWidget({@required this.controller});

  final name = _ServiceExtensionNameColumn();

  List<ColumnData<String>> get columns => [
        name,
      ];

  final IsolateStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    final extensions = controller.isolate?.extensionRPCs ?? [];
    return VMInfoCard(
      title: 'Service Extensions (${extensions.length})',
      table: Flexible(
        child: FlatTable<String>(
          columns: columns,
          data: extensions,
          keyFactory: (String extension) => ValueKey<String>(extension),
          sortColumn: name,
          sortDirection: SortDirection.ascending,
          onItemSelected: (_) => null,
        ),
      ),
    );
  }
}
