// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../tables.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/split.dart' as split;
import '../ui/ui_utils.dart';
import '../utils.dart';

import 'memory_controller.dart';
import 'memory_plotly.dart';
import 'memory_protocol.dart';

// TODO(devoncarew): expose _getAllocationProfile

class MemoryScreen extends Screen with SetStateMixin {
  MemoryScreen()
      : super(name: 'Memory', id: 'memory', iconClass: 'octicon-package') {
    classCountStatus = StatusItem();
    addStatusItem(classCountStatus);

    objectCountStatus = StatusItem();
    addStatusItem(objectCountStatus);
  }

  MemoryController memoryController = MemoryController();

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

  MemoryTracker memoryTracker;
  ProgressElement progressElement;

  @override
  void entering() {
    _updateListeningState();
  }

  void updateResumeButton({@required bool disabled}) {
    resumeButton.disabled = disabled;
    resumeButton.changeIcon(disabled
        ? FlutterIcons.resume_white_disabled_2x.src
        : FlutterIcons.resume_white_2x.src);
  }

  void updatePauseButton({@required bool disabled}) {
    pauseButton.disabled = disabled;
    pauseButton.changeIcon(disabled
        ? FlutterIcons.pause_black_disabled_2x.src
        : FlutterIcons.pause_black_2x.src);
  }

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div(c: 'custom-scrollbar')
      ..layoutVertical();

    resumeButton = PButton.icon('Resume', FlutterIcons.resume_white_disabled_2x)
      ..primary()
      ..small()
      ..disabled = true;

    pauseButton = PButton.icon('Pause', FlutterIcons.pause_black_2x)
      ..small()
      ..clazz('margin-left');

    // TODO(terry): Need to correctly handle enabled and disabled.
    vmMemorySnapshotButton = PButton.icon('Snapshot', FlutterIcons.snapshot,
        title: 'Memory Snapshot')
      ..small()
      ..clazz('margin-left')
      ..click(_loadAllocationProfile)
      ..disabled = true;
    resetAccumulatorsButton = PButton.icon(
        'Reset', FlutterIcons.resetAccumulators,
        title: 'Reset Accumulators')
      ..small()
      ..disabled = true;
    filterLibrariesButton =
    PButton.icon('Filter', FlutterIcons.filter, title: 'Filter')
      ..small()
      ..disabled = true;
    gcNowButton =
    PButton.icon('GC', FlutterIcons.gcNow, title: 'Manual Garbage Collect')
      ..small()
      ..click(_gcNow);

    resumeButton.click(() {
      memoryChart.resume();
    });

    pauseButton.click(() {
      memoryChart.pause();
    });

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              div(c: 'btn-group flex-no-wrap margin-left')
                ..add(<CoreElement>[
                  pauseButton,
                  resumeButton,
                ]),
              div(c: 'btn-group flex-no-wrap margin-left')
                ..add(<CoreElement>[
                  vmMemorySnapshotButton,
                  resetAccumulatorsButton,
                  filterLibrariesButton,
                  gcNowButton,
                ]),
            ]),
        ]),
      memoryChart = MemoryChart(this, memoryController)
        ..disabled = true,
      div(c: 'section'),
      tableContainer = div(c: 'section overflow-auto')
        ..layoutHorizontal()
        ..flex(),
    ]);

    _pushNextTable(null, _createHeapStatsTableView());

    bool splitterConfigured = false;

    if (!splitterConfigured) {
      split.flexSplit(
        [memoryChart, tableContainer],
        horizontal: false,
        gutterSize: defaultSplitterWidth,
        sizes: [18, 82],
        minSize: [200, 200],
      );
      splitterConfigured = true;
    }

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
      tableStack.addLast(next);
      tableContainer.add(next.element..clazz('margin-left'));
      tableContainer.element.scrollTo(<String, dynamic>{
        'left': tableContainer.element.scrollWidth,
        'top': 0,
        'behavior': 'smooth',
      });
    }
  }

  String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

  Future<Null> _loadAllocationProfile() async {
    vmMemorySnapshotButton.disabled = true;
    tableStack.first.element.display = null;
    final Spinner spinner =
    tableStack.first.element.add(Spinner()
      ..clazz('padded'));

    // TODO(devoncarew): error handling

    try {
      // 'reset': true to reset the object allocation accumulators
      final Response response = await serviceManager.service
          .callMethod('_getAllocationProfile', isolateId: _isolateId);
      final List<dynamic> members = response.json['members'];
      final List<ClassHeapStats> heapStats = members
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> d) => ClassHeapStats(d))
          .where((ClassHeapStats stats) {
        return stats.instancesCurrent > 0; //|| stats.instancesAccumulated > 0;
      }).toList();

      tableStack.first.setRows(heapStats);
      _updateStatus(heapStats);
      spinner.element.remove();
    } finally {
      vmMemorySnapshotButton.disabled = false;
    }
  }

  Future<Null> _gcNow() async {
    gcNowButton.disabled = true;

    try {
      // 'reset': true to reset the object allocation accumulators
      await serviceManager.service.callMethod('_getAllocationProfile',
          isolateId: _isolateId, args: {'gc': 'full'});
    } catch (e) {
      framework.toast('Unable to GC', title: 'Error');
      print('ERROR: $e');
    } finally {
      gcNowButton.disabled = false;
    }
  }

//  void _loadHeapSnapshot() {
//    List<Event> events = [];
//    Completer<List<Event>> graphEventsCompleter = new Completer();
//    StreamSubscription sub;
//
//    int received = 0;
//    sub = serviceInfo.service.onGraphEvent.listen((Event e) {
//      int index = e.json['chunkIndex'];
//      int count = e.json['chunkCount'];
//
//      print('received $index of $count');
//
//      if (events.length != count) {
//        events.length = count;
//        progressElement.max = count;
//      }
//
//      received++;
//
//      progressElement.value = received;
//
//      events[index] = e;
//
//      if (!events.any((e) => e == null)) {
//        sub.cancel();
//        graphEventsCompleter.complete(events);
//      }
//    });
//
//    loadSnapshotButton.disabled = true;
//    progressElement.value = 0;
//    progressElement.display = 'initial';
//
//    // TODO(devoncarew): snapshot info comes in as multiple binary _Graph events
//    serviceInfo.service
//        .requestHeapSnapshot(_isolateId, 'VM', true)
//        .catchError((e) {
//      framework.showError('Error retrieving heap snapshot', e);
//    });
//
//    graphEventsCompleter.future.then((List<Event> events) {
//      print('received ${events.length} heap snapshot events.');
//      toast('Snapshot download complete.');
//
//      // type, kind, isolate, timestamp, chunkIndex, chunkCount, nodeCount, _data
//      for (Event e in events) {
//        int nodeCount = e.json['nodeCount'];
//        ByteData data = e.json['_data'];
//        print('  $nodeCount nodes, ${data.lengthInBytes ~/ 1024}k data');
//      }
//    }).whenComplete(() {
//      print('done');
//      loadSnapshotButton.disabled = false;
//      progressElement.display = 'none';
//    });
//  }

  Table<ClassHeapStats> _createHeapStatsTableView() {
    final Table<ClassHeapStats> table = Table<ClassHeapStats>.virtual()
      ..element.display = 'none'
      ..element.clazz('memory-table');

    table.addColumn(MemoryColumnSize());
    table.addColumn(MemoryColumnInstanceCount());
    table.addColumn(MemoryColumnClassName());

    table.setSortColumn(table.columns.first);

    // table.onSelect.listen((ClassHeapStats row) async {
    //   final Table<InstanceSummary> newTable =
    //       row == null ? null : _createInstanceListTableView(row);
    //   _pushNextTable(table, newTable);
    // });

    return table;
  }

  void _updateStatus(List<ClassHeapStats> data) {
    if (data == null) {
      classCountStatus.element.text = '';
      objectCountStatus.element.text = '';
    } else {
      classCountStatus.element.text = '${nf.format(data.length)} classes';
      int objectCount = 0;
      for (ClassHeapStats stats in data) {
        objectCount += stats.instancesCurrent;
      }
      objectCountStatus.element.text = '${nf.format(objectCount)} objects';
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
}

class MemoryRow {
  MemoryRow(this.name, this.bytes, this.percentage);

  final String name;
  final int bytes;
  final double percentage;

  @override
  String toString() => name;
}

class MemoryColumnClassName extends Column<ClassHeapStats> {
  MemoryColumnClassName() : super('Class', wide: true);

  @override
  dynamic getValue(ClassHeapStats item) => item.classRef.name;
}

class MemoryColumnSize extends Column<ClassHeapStats> {
  MemoryColumnSize() : super('Size');

  @override
  bool get numeric => true;

  //String get cssClass => 'monospace';

  @override
  dynamic getValue(ClassHeapStats item) => item.bytesCurrent;

  @override
  String render(dynamic value) {
    if (value < 1024) {
      return ' ${Column.fastIntl(value)}';
    } else {
      return ' ${Column.fastIntl(value ~/ 1024)}k';
    }
  }
}

class MemoryColumnInstanceCount extends Column<ClassHeapStats> {
  MemoryColumnInstanceCount() : super('Count');

  @override
  bool get numeric => true;

  @override
  dynamic getValue(ClassHeapStats item) => item.instancesCurrent;

  @override
  String render(dynamic value) => Column.fastIntl(value);
}

class MemoryColumnSimple<T> extends Column<T> {
  MemoryColumnSimple(String name, this.getter, {bool wide = false})
      : super(name, wide: wide);

  String Function(T) getter;

  @override
  String getValue(T item) => getter(item);
}

class MemoryChart extends CoreElement {
  MemoryChart(this._memoryScreen, this._memoryController)
      : super('div', classes: 'section section-border') {
    flex();
    layoutVertical();

    element.id = _memoryGraph;
    element.style
      ..boxSizing = 'content-box'; // border-box causes right/left border cut.

    _memoryController.onMemory.listen((MemoryTracker memoryTracker) {
      if (!_memoryController.memoryTracker.hasConnection) {
        // VM Service connection has stopped.
        _memoryScreen.serviceDisconnet();
      } else {
        updateChart(memoryTracker);
      }
    });
  }

  static const String _memoryGraph = 'memory_timeline';

  final MemoryScreen _memoryScreen;
  final MemoryController _memoryController;

  bool _chartCreated = false;
  MemoryPlotly _plotlyChart;

  void updateChart(MemoryTracker data) {
    if (!_chartCreated) {
      _plotlyChart = MemoryPlotly(_memoryGraph, this)..plotMemory();
      _chartCreated = true;
    }

    for (HeapSample newSample in data.samples) {
      _plotlyChart.plotMemoryDataList(
        [newSample.timestamp],
        [newSample.rss],
        [newSample.capacity],
        [newSample.used],
        [newSample.external],
      );

      // TODO(terry): Need to add glyph to a GC trace.  Noticing GC within 100ms
      // of last GC should be ignored (same GC?). Check with VM folks.
      if (newSample.isGC) print('GC Occurred ${newSample.timestamp}');
    }
    data.samples.clear();
  }

  void pause() {
    _memoryScreen.updatePauseButton(disabled: true);
    _memoryScreen.updateResumeButton(disabled: false);

    _plotlyChart.liveUpdate = false;
  }

  void resume() {
    _memoryScreen.updateResumeButton(disabled: true);
    _memoryScreen.updatePauseButton(disabled: false);

    _plotlyChart.liveUpdate = true;
  }
}

// {
//   type: ClassHeapStats,
//   class: {type: @Class, fixedId: true, id: classes/5, name: Class},
//   new: [0, 0, 0, 0, 0, 0, 0, 0],
//   old: [3892, 809536, 3892, 809536, 0, 0, 0, 0],
//   promotedInstances: 0,
//   promotedBytes: 0
// }
class ClassHeapStats {
  ClassHeapStats(this.json) {
    classRef = ClassRef.parse(json['class']);
    _update(json['new']);
    _update(json['old']);
  }

  static const int ALLOCATED_BEFORE_GC = 0;
  static const int ALLOCATED_BEFORE_GC_SIZE = 1;
  static const int LIVE_AFTER_GC = 2;
  static const int LIVE_AFTER_GC_SIZE = 3;
  static const int ALLOCATED_SINCE_GC = 4;
  static const int ALLOCATED_SINCE_GC_SIZE = 5;
  static const int ACCUMULATED = 6;
  static const int ACCUMULATED_SIZE = 7;

  final Map<String, dynamic> json;

  int instancesCurrent = 0;
  int instancesAccumulated = 0;
  int bytesCurrent = 0;
  int bytesAccumulated = 0;

  ClassRef classRef;

  String get type => json['type'];

  void _update(List<dynamic> stats) {
    instancesAccumulated += stats[ACCUMULATED];
    bytesAccumulated += stats[ACCUMULATED_SIZE];
    instancesCurrent += stats[LIVE_AFTER_GC] + stats[ALLOCATED_SINCE_GC];
    bytesCurrent += stats[LIVE_AFTER_GC_SIZE] + stats[ALLOCATED_SINCE_GC_SIZE];
  }

  @override
  String toString() =>
      '[ClassHeapStats type: $type, class: ${classRef.name}, count: $instancesCurrent, bytes: $bytesCurrent]';
}
