// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../primitives/utils.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/table.dart';
import '../../../shared/table_data.dart';
import '../../../shared/theme.dart';
import '../vm_developer_common_widgets.dart';
import '../vm_developer_tools_screen.dart';
import '../vm_service_private_extensions.dart';
import 'vm_statistics_view_controller.dart';

class VMStatisticsView extends VMDeveloperView {
  const VMStatisticsView()
      : super(
          id,
          title: 'VM',
          icon: Icons.devices,
        );
  static const id = 'vm-statistics';

  @override
  Widget build(BuildContext context) => VMStatisticsViewBody();
}

/// Displays general information about the state of the Dart VM.
class VMStatisticsViewBody extends StatelessWidget {
  final controller = VMStatisticsViewController();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefreshButton(onPressed: controller.refresh),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: controller.refreshing,
            builder: (context, _, __) {
              return VMStatisticsWidget(
                controller: controller,
              );
            },
          ),
        ),
      ],
    );
  }
}

class VMStatisticsWidget extends StatelessWidget {
  const VMStatisticsWidget({required this.controller});

  final VMStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: GeneralVMStatisticsWidget(
                  controller: controller,
                ),
              ),
              Expanded(
                child: ProcessStatisticsWidget(
                  controller: controller,
                ),
              )
            ],
          ),
        ),
        Flexible(
          flex: 4,
          child: Column(
            children: [
              Flexible(
                child: IsolatesPreviewWidget(
                  controller: controller,
                ),
              ),
              Flexible(
                child: IsolatesPreviewWidget(
                  controller: controller,
                  systemIsolates: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Displays general information about the VM instance, including:
///   - VM debug name
///   - Dart version
///   - Embedder name
///   - Start time
///   - Profiler mode
///   - Current memory consumption
class GeneralVMStatisticsWidget extends StatelessWidget {
  const GeneralVMStatisticsWidget({required this.controller});

  final VMStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    final vm = controller.vm;
    return OutlineDecoration(
      child: VMInfoCard(
        title: 'VM',
        rowKeyValues: [
          selectableTextBuilderMapEntry('Name', vm?.name),
          selectableTextBuilderMapEntry('Version', vm?.version),
          selectableTextBuilderMapEntry('Embedder', vm?.embedder),
          selectableTextBuilderMapEntry(
            'Started',
            vm == null
                ? null
                : formatDateTime(
                    DateTime.fromMillisecondsSinceEpoch(vm.startTime!),
                  ),
          ),
          selectableTextBuilderMapEntry('Profiler Mode', vm?.profilerMode),
          selectableTextBuilderMapEntry(
            'Current Memory',
            prettyPrintBytes(
              vm?.currentMemory,
              includeUnit: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays information about the current VM process, including:
///   - Process ID
///   - Host CPU
///   - Target CPU
///   - OS
///   - Current and maximum resident set size (RSS) utilization
///   - Zone allocator memory utilization
class ProcessStatisticsWidget extends StatelessWidget {
  const ProcessStatisticsWidget({required this.controller});

  final VMStatisticsViewController controller;

  @override
  Widget build(BuildContext context) {
    final vm = controller.vm;
    return OutlineDecoration(
      showTop: false,
      child: VMInfoCard(
        title: 'Process',
        rowKeyValues: [
          selectableTextBuilderMapEntry('PID', vm?.pid?.toString()),
          selectableTextBuilderMapEntry(
            'Host CPU',
            vm == null ? null : '${vm.hostCPU} (${vm.architectureBits}-bits)',
          ),
          selectableTextBuilderMapEntry('Target CPU', vm?.targetCPU),
          selectableTextBuilderMapEntry(
            'Operating System',
            vm?.operatingSystem,
          ),
          selectableTextBuilderMapEntry(
            'Max Memory (RSS)',
            prettyPrintBytes(
              vm?.maxRSS,
              includeUnit: true,
            ),
          ),
          selectableTextBuilderMapEntry(
            'Current Memory (RSS)',
            prettyPrintBytes(
              vm?.currentRSS,
              includeUnit: true,
            ),
          ),
          selectableTextBuilderMapEntry(
            'Zone Memory',
            prettyPrintBytes(
              vm?.nativeZoneMemoryUsage,
              includeUnit: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _IsolateNameColumn extends ColumnData<Isolate> {
  _IsolateNameColumn() : super.wide('Name');

  @override
  String getValue(Isolate i) => i.name!;
}

class _IsolateIDColumn extends ColumnData<Isolate> {
  _IsolateIDColumn() : super.wide('ID');

  @override
  String getValue(Isolate i) => i.number!;
}

abstract class _IsolateMemoryColumn extends ColumnData<Isolate> {
  _IsolateMemoryColumn(String title) : super.wide(title);

  int getCapacity(Isolate i);
  int getUsage(Isolate i);

  @override
  String getValue(Isolate i) {
    return '${prettyPrintBytes(getUsage(i), includeUnit: true)} '
        'of ${prettyPrintBytes(getCapacity(i), includeUnit: true)}';
  }
}

class _IsolateNewSpaceColumn extends _IsolateMemoryColumn {
  _IsolateNewSpaceColumn() : super('New Space');

  @override
  int getCapacity(Isolate i) => i.newSpaceCapacity;

  @override
  int getUsage(Isolate i) => i.newSpaceUsage;
}

class _IsolateOldSpaceColumn extends _IsolateMemoryColumn {
  _IsolateOldSpaceColumn() : super('Old Space');

  @override
  int getCapacity(Isolate i) => i.oldSpaceCapacity;

  @override
  int getUsage(Isolate i) => i.oldSpaceUsage;
}

class _IsolateHeapColumn extends _IsolateMemoryColumn {
  _IsolateHeapColumn() : super('Heap');

  @override
  int getCapacity(Isolate i) => i.dartHeapCapacity;

  @override
  int getUsage(Isolate i) => i.dartHeapSize;
}

/// Displays general statistics about running isolates including:
///   - Isolate debug name
///   - VM Isolate ID
///   - New / old space usage
///   - Dart heap usage
class IsolatesPreviewWidget extends StatelessWidget {
  IsolatesPreviewWidget({
    required this.controller,
    this.systemIsolates = false,
  });

  final name = _IsolateNameColumn();
  final number = _IsolateIDColumn();
  final newSpace = _IsolateNewSpaceColumn();
  final oldSpace = _IsolateOldSpaceColumn();
  final heap = _IsolateHeapColumn();

  List<ColumnData<Isolate>> get columns => [
        name,
        number,
        newSpace,
        oldSpace,
        heap,
      ];

  final VMStatisticsViewController controller;
  final bool systemIsolates;

  @override
  Widget build(BuildContext context) {
    final title = systemIsolates ? 'System Isolates' : 'Isolates';
    final isolates =
        systemIsolates ? controller.systemIsolates : controller.isolates;
    return OutlineDecoration(
      showLeft: false,
      showTop: !systemIsolates,
      child: VMInfoCard(
        title: '$title (${isolates.length})',
        table: Flexible(
          child: FlatTable<Isolate>(
            columns: columns,
            data: isolates,
            keyFactory: (Isolate i) => ValueKey<String>(i.id!),
            sortColumn: name,
            sortDirection: SortDirection.descending,
            onItemSelected: (_) => null,
          ),
        ),
      ),
    );
  }
}
