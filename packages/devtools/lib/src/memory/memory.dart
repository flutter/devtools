// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools/src/debugger/debugger_state.dart';
import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../tables.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../utils.dart';
import 'memory_chart.dart';
import 'memory_controller.dart';
import 'memory_data_view.dart';
import 'memory_detail.dart';
import 'memory_protocol.dart';

class MemoryScreen extends Screen with SetStateMixin {
  MemoryScreen({bool disabled, String disabledTooltip})
      : _debuggerState = DebuggerState(),
        super(
          name: 'Memory',
          id: 'memory',
          iconClass: 'octicon-package',
          disabled: disabled,
          disabledTooltip: disabledTooltip,
        ) {
    classCountStatus = StatusItem();
    addStatusItem(classCountStatus);

    objectCountStatus = StatusItem();
    addStatusItem(objectCountStatus);
  }

  final MemoryController memoryController = MemoryController();

  StatusItem classCountStatus;
  StatusItem objectCountStatus;

  PButton pauseButton;
  PButton resumeButton;

  PButton vmMemorySnapshotButton;
  PButton resetAccumulatorsButton;
  PButton filterLibrariesButton;
  PButton gcNowButton;

  ListQueue<Table<Object>> tableStack = ListQueue<Table<Object>>();
  MemoryChart memoryChart;
  CoreElement tableContainer;

  final DebuggerState _debuggerState;
  MemoryDataView memoryDataView;

  MemoryTracker memoryTracker;
  ProgressElement progressElement;

  @override
  void entering() {
    _updateListeningState();
  }

  @override
  void exiting() {
    framework.clearMessages();
  }

  void updateResumeButton({@required bool disabled}) {
    resumeButton.disabled = disabled;
  }

  void updatePauseButton({@required bool disabled}) {
    pauseButton.disabled = disabled;
  }

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    resumeButton = PButton.icon('Resume', FlutterIcons.resume_white_disabled_2x)
      ..primary()
      ..small()
      ..disabled = true;

    pauseButton = PButton.icon('Pause', FlutterIcons.pause_black_2x)..small();

    // TODO(terry): Need to correctly handle enabled and disabled.
    vmMemorySnapshotButton = PButton.icon('Snapshot', FlutterIcons.snapshot,
        title: 'Memory Snapshot')
      ..clazz('margin-left')
      ..small()
      ..click(_loadAllocationProfile)
      ..disabled = true;
    resetAccumulatorsButton = PButton.icon(
        'Reset', FlutterIcons.resetAccumulators,
        title: 'Reset Accumulators')
      ..small()
      ..click(_resetAllocatorCounts)
      ..disabled = true;
    filterLibrariesButton =
        PButton.icon('Filter', FlutterIcons.filter, title: 'Filter')
          ..small()
          ..disabled = true;
    gcNowButton =
        PButton.icon('GC', FlutterIcons.gcNow, title: 'Manual Garbage Collect')
          ..small()
          ..click(_gcNow)
          ..disabled = true;

    resumeButton.click(() {
      ga.select(ga.memory, ga.resume);

      updateResumeButton(disabled: true);
      updatePauseButton(disabled: false);

      memoryChart.resume();
    });

    pauseButton.click(() {
      ga.select(ga.memory, ga.pause);

      updatePauseButton(disabled: true);
      updateResumeButton(disabled: false);

      memoryChart.pause();
    });

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              div(c: 'btn-group flex-no-wrap')
                ..add(<CoreElement>[
                  pauseButton,
                  resumeButton,
                ]),
              div()..flex(),
              div(c: 'btn-group collapsible-700 flex-no-wrap margin-left')
                ..add(<CoreElement>[
                  vmMemorySnapshotButton,
                  resetAccumulatorsButton,
                  filterLibrariesButton,
                  gcNowButton,
                ]),
            ]),
        ]),
      memoryChart = MemoryChart(memoryController)..disabled = true,
      tableContainer = div(c: 'section overflow-auto')
        ..layoutHorizontal()
        ..flex(),
    ]);

    memoryController.onDisconnect.listen((__) {
      serviceDisconnet();
    });

    maybeShowDebugWarning(framework);

    _pushNextTable(null, _createHeapStatsTableView());

    _updateStatus(null);

    return screenDiv;
  }

  void _pushNextTable(Table<dynamic> current, Table<dynamic> next) {
    // Remove any tables to the right of current from the DOM and the stack.
    while (tableStack.length > 1 && tableStack.last != current) {
      tableStack.removeLast()
        ..element.element.remove()
        ..dispose();
    }

    // Push the new table on to the stack and to the right of current.
    if (next != null) {
      final bool isFirst = tableStack.isEmpty;

      tableStack.addLast(next);
      tableContainer.add(next.element);

      if (!isFirst) {
        next.element.clazz('margin-left');
      }

      tableContainer.element.scrollTo(<String, dynamic>{
        'left': tableContainer.element.scrollWidth,
        'top': 0,
        'behavior': 'smooth',
      });
    }
  }

  Future<void> _resetAllocatorCounts() async {
    ga.select(ga.memory, ga.reset);

    memoryChart.plotReset();

    resetAccumulatorsButton.disabled = true;
    tableStack.first.element.display = null;
    final Spinner spinner =
        tableStack.first.element.add(Spinner()..clazz('padded'));

    try {
      final List<ClassHeapDetailStats> heapStats =
          await memoryController.resetAllocationProfile();
      tableStack.first.setRows(heapStats);
      _updateStatus(heapStats);
      spinner.element.remove();
    } catch (e) {
      framework.toast('Reset failed ${e.toString()}', title: 'Error');
    } finally {
      resetAccumulatorsButton.disabled = false;
    }
  }

  Future<void> _loadAllocationProfile({bool reset = false}) async {
    ga.select(ga.memory, ga.snapshot);

    memoryChart.plotSnapshot();

    vmMemorySnapshotButton.disabled = true;
    tableStack.first.element.display = null;
    final Spinner spinner =
        tableStack.first.element.add(Spinner()..clazz('padded'));

    try {
      final List<ClassHeapDetailStats> heapStats =
          await memoryController.getAllocationProfile();
      tableStack.first.setRows(heapStats);
      _updateStatus(heapStats);
      spinner.element.remove();
    } catch (e) {
      framework.toast('Snapshot failed ${e.toString()}', title: 'Error');
    } finally {
      vmMemorySnapshotButton.disabled = false;
    }
  }

  Future<Null> _gcNow() async {
    ga.select(ga.memory, ga.gC);

    gcNowButton.disabled = true;

    try {
      await memoryController.gc();
    } catch (e) {
      framework.toast('Unable to GC ${e.toString()}', title: 'Error');
    } finally {
      gcNowButton.disabled = false;
    }
  }

  void _updateListeningState() async {
    await serviceManager.serviceAvailable.future;

    final bool shouldBeRunning = isCurrentScreen;

    if (shouldBeRunning && !memoryController.hasStarted) {
      await memoryController.startTimeline();

      pauseButton.disabled = false;
      resumeButton.disabled = true;

      vmMemorySnapshotButton.disabled = false;
      resetAccumulatorsButton.disabled = false;
      gcNowButton.disabled = false;

      memoryChart.disabled = false;
    }
  }

  // VM Service has stopped (disconnected).
  void serviceDisconnet() {
    pauseButton.disabled = true;
    resumeButton.disabled = true;

    vmMemorySnapshotButton.disabled = true;
    resetAccumulatorsButton.disabled = true;
    filterLibrariesButton.disabled = true;
    gcNowButton.disabled = true;

    memoryChart.disabled = true;
  }

  void _removeInstanceView() {
    if (tableContainer.element.children.length == 3) {
      tableContainer.element.children.removeLast();
    }
  }

  Table<ClassHeapDetailStats> _createHeapStatsTableView() {
    final Table<ClassHeapDetailStats> table =
        Table<ClassHeapDetailStats>.virtual()
          ..element.display = 'none'
          ..element.clazz('memory-table');

    table.addColumn(MemoryColumnSize());
    table.addColumn(MemoryColumnInstanceCount());
    table.addColumn(MemoryColumnInstanceAccumulatedCount());
    table.addColumn(MemoryColumnClassName());

    table.setSortColumn(table.columns.first);

    table.onSelect.listen((ClassHeapDetailStats row) async {
      ga.select(ga.memory, ga.inspectClass);

      // User selected a new class from the list of classes so the instance view
      // which would be the third child needs to be removed.
      _removeInstanceView();

      final Table<InstanceSummary> newTable =
          row == null ? null : await _createInstanceListTableView(row);
      _pushNextTable(table, newTable);
    });

    return table;
  }

  Future<Table<InstanceSummary>> _createInstanceListTableView(
      ClassHeapDetailStats row) async {
    final Table<InstanceSummary> table = new Table<InstanceSummary>.virtual()
      ..element.clazz('memory-table');

    try {
      final List<InstanceSummary> instanceRows =
          await memoryController.getInstances(
        row.classRef.id,
        row.classRef.name,
        row.instancesCurrent,
      );

      table.addColumn(new MemoryColumnSimple<InstanceSummary>(
          '${instanceRows.length} Instances of ${row.classRef.name}',
          (InstanceSummary row) => row.objectRef));

      table.setRows(instanceRows);
    } catch (e) {
      framework.toast(
        'Problem fetching instances of ${row.classRef.name}: $e',
        title: 'Error',
      );
    }

    table.onSelect.listen((InstanceSummary row) async {
      ga.select(ga.memory, ga.inspectInstance);

      // User selected a new instance from the list of class instances so the
      // instance view which would be the third child needs to be removed.
      _removeInstanceView();

      Instance instance;
      try {
        instance = await memoryController.getObject(row.objectRef);
      } catch (e) {
        instance = null; // Signal a problem
      } finally {
        tableContainer.add(_createInstanceView(
          instance != null
              ? row.objectRef
              : 'Unable to fetch instance ${row.objectRef}',
          row.className,
        ));

        tableContainer.element.scrollTo(<String, dynamic>{
          'left': tableContainer.element.scrollWidth,
          'top': 0,
          'behavior': 'smooth',
        });

        // Allow inspection of the memory object.
        memoryDataView.showFields(instance != null ? instance.fields : []);
      }
    });

    return table;
  }

  CoreElement _createInstanceView(String objectRef, String className) {
    final MemoryDescriber describer = (BoundField field) async {
      if (field == null) {
        return null;
      }

      final dynamic value = field.value;

      // TODO(terry): Replace two if's with switch (value.runtimeType)
      if (value is Sentinel) {
        return value.valueAsString;
      }

      if (value is TypeArgumentsRef) {
        return value.name;
      }

      final Instance ref = value;

      if (ref.valueAsString != null && !ref.valueAsStringIsTruncated) {
        return ref.valueAsString;
      } else {
        final dynamic result = await serviceManager.service.invoke(
          _debuggerState.isolateRef.id,
          ref.id,
          'toString',
          <String>[],
          disableBreakpoints: true,
        );

        if (result is ErrorRef) {
          return '${result.kind} ${result.message}';
        } else if (result is InstanceRef) {
          final String str = await _retrieveFullStringValue(result);
          return str;
        } else {
          // TODO: Improve the return value for this case.
          return null;
        }
      }
    };

    memoryDataView = MemoryDataView(memoryController, describer);

    return div(
        c: 'table-border table-virtual memory-table margin-left debugger-menu')
      ..layoutVertical()
      ..add(<CoreElement>[
        div(
          text: '$className instance $objectRef',
          c: 'memory-inspector',
        ),
        memoryDataView.element,
      ]);
  }

  // TODO(terry): Move to common file shared by debugger and memory.
  Future<String> _retrieveFullStringValue(InstanceRef stringRef) async {
    if (stringRef.valueAsStringIsTruncated != true) {
      return stringRef.valueAsString;
    }

    final dynamic result = await serviceManager.service.getObject(
      _debuggerState.isolateRef.id,
      stringRef.id,
      offset: 0,
      count: stringRef.length,
    );
    if (result is Instance) {
      final Instance obj = result;
      return obj.valueAsString;
    } else {
      return '${stringRef.valueAsString}...';
    }
  }

  void _updateStatus(List<ClassHeapDetailStats> data) {
    if (data == null) {
      classCountStatus.element.text = '';
      objectCountStatus.element.text = '';
    } else {
      classCountStatus.element.text = '${nf.format(data.length)} classes';
      int objectCount = 0;
      for (ClassHeapDetailStats stats in data) {
        objectCount += stats.instancesCurrent;
      }
      objectCountStatus.element.text = '${nf.format(objectCount)} objects';
    }
  }
}
