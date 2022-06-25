// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../profiler/cpu_profiler.dart';
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
              Flexible(
                flex: 3,
                child: GeneralIsolateStatisticsWidget(
                  controller: controller,
                ),
              ),
              Flexible(
                flex: 2,
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
            ],
          ),
        ),
      ],
    );
  }
}

/// A table which displays the amount of time the VM is performing certain
/// tagged tasks.
class TagStatisticsWidget extends StatelessWidget {
  TagStatisticsWidget({required this.controller});

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
  const IsolatePortsWidget({required this.controller});

  final IsolateStatisticsViewController controller;

  @override
  _IsolatePortsWidgetState createState() => _IsolatePortsWidgetState();
}

class _IsolatePortsWidgetState extends State<IsolatePortsWidget> {
  final id = _PortIDColumn();
  final name = _PortNameColumn();

  final selectedPort = ValueNotifier<InstanceRef?>(null);

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
                initialFractions: const [
                  0.3,
                  0.7,
                ],
                children: [
                  FlatTable<InstanceRef?>(
                    columns: columns,
                    data: ports,
                    keyFactory: (InstanceRef? port) =>
                        ValueKey<String>(port!.debugName!),
                    sortColumn: id,
                    sortDirection: SortDirection.ascending,
                    selectionNotifier: selectedPort,
                    onItemSelected: (InstanceRef? port) => setState(
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
  ServiceExtensionsWidget({required this.controller});

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
