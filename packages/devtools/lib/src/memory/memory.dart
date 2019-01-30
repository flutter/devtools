// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../charts/charts.dart';
import '../framework/framework.dart';
import '../globals.dart';
import '../tables.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../utils.dart';
import '../vm_service_wrapper.dart';

// TODO(devoncarew): expose _getAllocationProfile

// TODO(devoncarew): have a 'show vm objects' checkbox

class MemoryScreen extends Screen {
  MemoryScreen()
      : super(name: 'Memory', id: 'memory', iconClass: 'octicon-package') {
    classCountStatus = StatusItem();
    addStatusItem(classCountStatus);

    objectCountStatus = StatusItem();
    addStatusItem(objectCountStatus);
  }

  StatusItem classCountStatus;
  StatusItem objectCountStatus;

  PButton loadSnapshotButton;

  ListQueue<Table<Object>> tableStack = ListQueue<Table<Object>>();
  CoreElement tableContainer;

  MemoryChart memoryChart;
  SetStateMixin memoryChartStateMixin = SetStateMixin();
  MemoryTracker memoryTracker;
  ProgressElement progressElement;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    screenDiv.add(<CoreElement>[
      createLiveChartArea(),
      div(c: 'section'),
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              loadSnapshotButton = PButton('Load heap snapshot')
                ..small()
                ..primary()
                ..disabled = true
                ..click(_loadAllocationProfile),
              progressElement = ProgressElement()
                ..clazz('margin-left')
                ..display = 'none',
              div()..flex(),
            ])
        ]),
      tableContainer = div(c: 'section overflow-auto')..layoutHorizontal()
    ]);

    _pushNextTable(null, _createHeapStatsTableView());

    _updateStatus(null);

    // TODO(devoncarew): don't rebuild until the component is active
    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      _handleIsolateChanged();
    });

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

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

  void _handleIsolateChanged() {
    // TODO(devoncarew): update buttons
  }

  String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

  Future<Null> _loadAllocationProfile() async {
    loadSnapshotButton.disabled = true;
    tableStack.first.element.display = null;
    final Spinner spinner =
        tableStack.first.element.add(Spinner()..clazz('padded'));

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
      loadSnapshotButton.disabled = false;
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

  CoreElement createLiveChartArea() {
    final CoreElement container = div(c: 'section perf-chart table-border')
      ..layoutVertical();
    memoryChart = MemoryChart(container);
    memoryChart.disabled = true;
    return container;
  }

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

  void _handleConnectionStart(VmServiceWrapper service) {
    loadSnapshotButton.disabled = false;
    memoryChart.disabled = false;

    memoryTracker = MemoryTracker(service);
    memoryTracker.start();

    memoryTracker.onChange.listen((Null _) {
      memoryChartStateMixin.setState(() {
        memoryChart.updateFrom(memoryTracker);
      });
    });
  }

  void _handleConnectionStop(dynamic event) {
    loadSnapshotButton.disabled = true;
    memoryChart.disabled = true;

    memoryTracker?.stop();
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

class MemoryChart extends LineChart<MemoryTracker> {
  MemoryChart(CoreElement parent) : super(parent, classes: 'perf-chart') {
    processLabel = parent.add(div(c: 'perf-label'));
    processLabel.element.style.left = '0';

    heapLabel = parent.add(div(c: 'perf-label'));
    heapLabel.element.style.right = '0';
  }

  CoreElement processLabel;
  CoreElement heapLabel;

  @override
  void update(MemoryTracker data) {
    if (data.samples.isEmpty || dim == null) {
      // TODO:
      return;
    }

    // display the process usage
    final String rss = '${printMb(data.processRss ?? 0, 0)} MB RSS';
    processLabel.text = rss;

    // display the dart heap usage
    final String used =
        '${printMb(data.currentHeap, 1)} of ${printMb(data.heapMax, 1)} MB';
    heapLabel.text = used;

    // re-render the svg

    // Make the y height large enough for the largest sample,
    const int tenMB = 1024 * 1024 * 10;
    final int top = (data.maxHeapData ~/ tenMB) * tenMB + tenMB;

    final int width = MemoryTracker.kMaxGraphTime.inMilliseconds;
    final int right = data.samples.last.time;

    // TODO(devoncarew): draw dots for GC events?

    chartElement.setInnerHtml('''
            <svg viewBox="0 0 ${dim.x} ${LineChart.fixedHeight}">
            <polyline
                fill="none"
                stroke="#0074d9"
                stroke-width="3"
                points="${createPoints(data.samples, top, width, right)}"/>
            </svg>
            ''');
  }

  String createPoints(List<HeapSample> samples, int top, int width, int right) {
    // 0,120 20,60 40,80 60,20
    return samples.map((HeapSample sample) {
      final int x = dim.x - ((right - sample.time) * dim.x ~/ width);
      final int y = dim.y - (sample.bytes * dim.y ~/ top);
      return '$x,$y';
    }).join(' ');
  }
}

class MemoryTracker {
  MemoryTracker(this.service);

  static const Duration kMaxGraphTime = Duration(minutes: 1);
  static const Duration kUpdateDelay = Duration(seconds: 1);

  VmServiceWrapper service;
  Timer _pollingTimer;
  final StreamController<Null> _changeController =
      StreamController<Null>.broadcast();

  final List<HeapSample> samples = <HeapSample>[];
  final Map<String, List<HeapSpace>> isolateHeaps = <String, List<HeapSpace>>{};
  int heapMax;
  int processRss;

  bool get hasConnection => service != null;

  Stream<Null> get onChange => _changeController.stream;

  int get currentHeap => samples.last.bytes;

  int get maxHeapData {
    return samples.fold<int>(heapMax,
        (int value, HeapSample sample) => math.max(value, sample.bytes));
  }

  void start() {
    _pollingTimer = Timer(const Duration(milliseconds: 100), _pollMemory);
    service.onGCEvent.listen(_handleGCEvent);
  }

  void stop() {
    _pollingTimer?.cancel();
    service = null;
  }

  void _handleGCEvent(Event event) {
    //final bool ignore = event.json['reason'] == 'compact';

    final List<HeapSpace> heaps = <HeapSpace>[
      HeapSpace.parse(event.json['new']),
      HeapSpace.parse(event.json['old'])
    ];
    _updateGCEvent(event.isolate.id, heaps);
  }

  Future<Null> _pollMemory() async {
    if (!hasConnection) {
      return;
    }

    final VM vm = await service.getVM();
    final List<Isolate> isolates =
        await Future.wait(vm.isolates.map((IsolateRef ref) async {
      return await service.getIsolate(ref.id);
    }));
    _update(vm, isolates);

    _pollingTimer = Timer(kUpdateDelay, _pollMemory);
  }

  // TODO(devoncarew): add a way to pause polling

  void _update(VM vm, List<Isolate> isolates) {
    processRss = vm.json['_currentRSS'];

    isolateHeaps.clear();

    for (Isolate isolate in isolates) {
      final List<HeapSpace> heaps = getHeaps(isolate).toList();
      isolateHeaps[isolate.id] = heaps;
    }

    _recalculate();
  }

  void _updateGCEvent(String id, List<HeapSpace> heaps) {
    isolateHeaps[id] = heaps;
    _recalculate(true);
  }

  void _recalculate([bool fromGC = false]) {
    int current = 0;
    int total = 0;

    for (List<HeapSpace> heaps in isolateHeaps.values) {
      current += heaps.fold<int>(
          0, (int i, HeapSpace heap) => i + heap.used + heap.external);
      total += heaps.fold<int>(
          0, (int i, HeapSpace heap) => i + heap.capacity + heap.external);
    }

    heapMax = total;

    int time = DateTime.now().millisecondsSinceEpoch;
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.time);
    }

    _addSample(HeapSample(current, time, fromGC));
  }

  void _addSample(HeapSample sample) {
    if (samples.isEmpty) {
      // Add an initial synthetic sample so the first version of the graph draws some data.
      samples.add(HeapSample(
          sample.bytes, sample.time - kUpdateDelay.inMilliseconds ~/ 4, false));
    }

    samples.add(sample);

    // delete old samples
    final int oldestTime =
        (DateTime.now().subtract(kMaxGraphTime).subtract(kUpdateDelay * 2))
            .millisecondsSinceEpoch;
    samples.retainWhere((HeapSample sample) => sample.time >= oldestTime);

    _changeController.add(null);
  }

  // TODO(devoncarew): fix HeapSpace.parse upstream
  static Iterable<HeapSpace> getHeaps(Isolate isolate) {
    final Map<String, dynamic> heaps = isolate.json['_heaps'];
    return heaps.values.map((dynamic json) => HeapSpace.parse(json));
  }
}

class HeapSample {
  HeapSample(this.bytes, this.time, this.isGC);

  final int bytes;
  final int time;
  final bool isGC;
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
