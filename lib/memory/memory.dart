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

// TODO(devoncarew): expose _getAllocationProfile

// TODO(devoncarew): have a 'show vm objects' checkbox

class MemoryScreen extends Screen {
  StatusItem classCountStatus;
  StatusItem objectCountStatus;

  PButton loadSnapshotButton;

  // TODO(dantup): Is it reasonable to put dynamic here?
  ListQueue<Table<dynamic>> tableStack = ListQueue<Table<dynamic>>();
  CoreElement tableContainer;

  MemoryChart memoryChart;
  SetStateMixin memoryChartStateMixin = new SetStateMixin();
  MemoryTracker memoryTracker;
  ProgressElement progressElement;

  MemoryScreen()
      : super(name: 'Memory', id: 'memory', iconClass: 'octicon-package') {
    classCountStatus = new StatusItem();
    addStatusItem(classCountStatus);

    objectCountStatus = new StatusItem();
    addStatusItem(objectCountStatus);
  }

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    mainDiv.add(<CoreElement>[
      createLiveChartArea(),
      div(c: 'section'),
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add(<CoreElement>[
              loadSnapshotButton = new PButton('Load heap snapshot')
                ..small()
                ..primary()
                ..disabled = true
                ..click(_loadAllocationProfile),
              progressElement = new ProgressElement()
                ..clazz('margin-left')
                ..display = 'none',
              div()..flex(),
            ])
        ]),
      tableContainer = div(c: 'section')..layoutHorizontal()
    ]);

    _pushNextTable(null, _createHeapStatsTableView());

    _updateStatus(null);

    // TODO(devoncarew): don't rebuild until the component is active
    serviceInfo.isolateManager.onSelectedIsolateChanged.listen((_) {
      _handleIsolateChanged();
    });

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);
  }

  void _pushNextTable(Table<dynamic> current, Table<dynamic> next) {
    // Remove any tables to the right of current from the DOM and the stack.
    while (tableStack.length > 1 && tableStack.last != current) {
      tableStack.removeLast().element.element.remove();
    }

    // Push the new table on to the stack and to the right of current.
    if (next != null) {
      tableStack.addLast(next);
      tableContainer.add(next.element..clazz('margin-left'));
    }
  }

  void _handleIsolateChanged() {
    // TODO(devoncarew): update buttons
  }

  String get _isolateId => serviceInfo.isolateManager.selectedIsolate.id;

  Future<Null> _loadAllocationProfile() async {
    loadSnapshotButton.disabled = true;
    final Spinner spinner =
        tableStack.first.element.add(new Spinner()..clazz('padded'));

    // TODO(devoncarew): error handling

    try {
      // 'reset': true to reset the object allocation accumulators
      final Response response = await serviceInfo.service
          .callMethod('_getAllocationProfile', isolateId: _isolateId);
      final List<dynamic> members = response.json['members'];
      final List<ClassHeapStats> heapStats = members
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> d) => new ClassHeapStats(d))
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
    memoryChart = new MemoryChart(container);
    memoryChart.disabled = true;
    return container;
  }

  Table<ClassHeapStats> _createHeapStatsTableView() {
    final Table<ClassHeapStats> table = new Table<ClassHeapStats>.virtual();

    table.addColumn(new MemoryColumnSize());
    table.addColumn(new MemoryColumnInstanceCount());
    table.addColumn(new MemoryColumnClassName());

    table.setSortColumn(table.columns.first);

    table.onSelect.listen((ClassHeapStats row) async {
      final Table<InstanceSummary> newTable =
          row == null ? null : _createInstanceListTableView(row);
      _pushNextTable(table, newTable);
    });

    return table;
  }

  Table<InstanceSummary> _createInstanceListTableView(ClassHeapStats row) {
    final Table<InstanceSummary> table = new Table<InstanceSummary>.virtual();
    table.addColumn(new MemoryColumnSimple<InstanceSummary>(
        'Instance ID', (InstanceSummary row) => row.id));

    table.onSelect.listen((InstanceSummary row) async {
      final Table<InstanceData> newTable =
          row == null ? null : _createInstanceDetailsTableView(row);
      _pushNextTable(table, newTable);
    });

    // Kick off population of data for the table.
    serviceInfo.service
        .getObject(_isolateId, row.classRef.id)
        .then((dynamic result) {
      final Class c = result;
      // // TODO(dantup): Find out what we should actually be displaying here.
      // if (c.library.type == '@Library') {
      //   // user class
      // } else {
      //   // vm class (Code, Instructions, ...)
      // }

      final List<InstanceSummary> instanceRows = InstanceSummary.randomList(c);
      table.setRows(instanceRows);
    });

    return table;
  }

  Table<InstanceData> _createInstanceDetailsTableView(InstanceSummary row) {
    final Table<InstanceData> table = new Table<InstanceData>.virtual();
    final Spinner spinner = table.element.add(new Spinner()..clazz('padded'));
    table.addColumn(new MemoryColumnSimple<InstanceData>(
        'Name', (InstanceData row) => row.name));
    table.addColumn(new MemoryColumnSimple<InstanceData>(
        'Value', (InstanceData row) => row.value.toString()));

    table.onSelect.listen((InstanceData row) async {
      // TODO(dantup): Push the relevant table.
      // For literlals, do nothing?
      // For other objects, push an InstanceDetails table?
      // final Table<InstanceData> newTable =
      //     row == null ? null : _createInstanceDetailsTableView(row);
      // _pushNextTable(table, newTable);
    });

    // Kick off population of data for the table.
    // TODO: If it turns out not to be async work, remove the spinner.
    row.getData().then((List<InstanceData> data) {
      table.setRows(data);
      spinner.element.remove();
    });

    return table;
  }

  @override
  HelpInfo get helpInfo =>
      new HelpInfo(title: 'memory view docs', url: 'http://www.cheese.com');

  void _handleConnectionStart(VmService service) {
    loadSnapshotButton.disabled = false;
    memoryChart.disabled = false;

    memoryTracker = new MemoryTracker(service);
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
  final String name;
  final int bytes;
  final double percentage;

  MemoryRow(this.name, this.bytes, this.percentage);

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
  String Function(T) getter;
  MemoryColumnSimple(String name, this.getter, {bool wide = false})
      : super(name, wide: wide);

  @override
  String getValue(T item) => getter(item);
}

class MemoryChart extends LineChart<MemoryTracker> {
  CoreElement processLabel;
  CoreElement heapLabel;

  MemoryChart(CoreElement parent) : super(parent) {
    processLabel = parent.add(div(c: 'perf-label'));
    processLabel.element.style.left = '0';

    heapLabel = parent.add(div(c: 'perf-label'));
    heapLabel.element.style.right = '0';
  }

  @override
  void update(MemoryTracker data) {
    if (data.samples.isEmpty || dim == null) {
      // TODO:
      return;
    }

    // display the process usage
    final String rss = '${_printMb(data.processRss ?? 0, 0)} MB RSS';
    processLabel.text = rss;

    // display the dart heap usage
    final String used =
        '${_printMb(data.currentHeap, 1)} of ${_printMb(data.heapMax, 1)} MB';
    heapLabel.text = used;

    // re-render the svg

    // Make the y height large enough for the largest sample,
    const int tenMB = 1024 * 1024 * 10;
    final int top = (data.maxHeapData ~/ tenMB) * tenMB + tenMB;

    final int width = MemoryTracker.kMaxGraphTime.inMilliseconds;
    final int right = data.samples.last.time;

    // TODO(devoncarew): draw dots for GC events?

    chartElement.setInnerHtml('''
            <svg viewBox="0 0 ${dim.x} ${dim.y}">
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
  static const Duration kMaxGraphTime = Duration(minutes: 1);
  static const Duration kUpdateDelay = Duration(seconds: 1);

  VmService service;
  Timer _pollingTimer;
  final StreamController<Null> _changeController =
      new StreamController<Null>.broadcast();

  final List<HeapSample> samples = <HeapSample>[];
  final Map<String, List<HeapSpace>> isolateHeaps = <String, List<HeapSpace>>{};
  int heapMax;
  int processRss;

  MemoryTracker(this.service);

  bool get hasConnection => service != null;

  Stream<Null> get onChange => _changeController.stream;

  int get currentHeap => samples.last.bytes;

  int get maxHeapData {
    return samples.fold<int>(heapMax,
        (int value, HeapSample sample) => math.max(value, sample.bytes));
  }

  void start() {
    _pollingTimer = new Timer(const Duration(milliseconds: 100), _pollMemory);
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

    _pollingTimer = new Timer(kUpdateDelay, _pollMemory);
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

    int time = new DateTime.now().millisecondsSinceEpoch;
    if (samples.isNotEmpty) {
      time = math.max(time, samples.last.time);
    }

    _addSample(new HeapSample(current, time, fromGC));
  }

  void _addSample(HeapSample sample) {
    if (samples.isEmpty) {
      // Add an initial synthetic sample so the first version of the graph draws some data.
      samples.add(new HeapSample(
          sample.bytes, sample.time - kUpdateDelay.inMilliseconds ~/ 4, false));
    }

    samples.add(sample);

    // delete old samples
    final int oldestTime =
        (new DateTime.now().subtract(kMaxGraphTime).subtract(kUpdateDelay * 2))
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
  final int bytes;
  final int time;
  final bool isGC;

  HeapSample(this.bytes, this.time, this.isGC);
}

String _printMb(num bytes, int fractionDigits) =>
    (bytes / (1024 * 1024)).toStringAsFixed(fractionDigits);

// {
//   type: ClassHeapStats,
//   class: {type: @Class, fixedId: true, id: classes/5, name: Class},
//   new: [0, 0, 0, 0, 0, 0, 0, 0],
//   old: [3892, 809536, 3892, 809536, 0, 0, 0, 0],
//   promotedInstances: 0,
//   promotedBytes: 0
// }
class ClassHeapStats {
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

  ClassHeapStats(this.json) {
    classRef = ClassRef.parse(json['class']);
    _update(json['new']);
    _update(json['old']);
  }

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

class InstanceSummary {
  Class clazz;
  String id;

  InstanceSummary(this.clazz, this.id);
  @override
  String toString() => '[InstanceSummary id: $id, class: ${clazz.name}]';

  // TODO(dantup): Remove this once we have real data.
  static List<InstanceSummary> randomList(Class clazz) {
    return new List<InstanceSummary>.generate(
        1000, (int i) => new InstanceSummary(clazz, 'objects/$i'));
  }

  Future<List<InstanceData>> getData() async {
    // TODO(dantup): Replace with real implementation.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return <InstanceData>[
      new InstanceData('id', id),
      new InstanceData('name', 'Joe Bloggs'),
      new InstanceData('email', 'something@example.org'),
      new InstanceData('company', 'Bloggs Corp'),
      new InstanceData('telephone', '01234 567 890'),
      new InstanceData('shoeSize', 11),
    ];
  }
}

class InstanceData {
  String name;
  dynamic value;

  InstanceData(this.name, this.value);

  @override
  String toString() => '[InstanceData name: $name, value: $value]';
}
