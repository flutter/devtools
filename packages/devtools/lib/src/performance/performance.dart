// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../charts/charts.dart';
import '../framework/framework.dart';
import '../globals.dart';
import '../tables.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../utils.dart';
import '../vm_service_wrapper.dart';

class PerformanceScreen extends Screen {
  PerformanceScreen()
      : super(
            name: 'Performance',
            id: 'performance',
            iconClass: 'octicon-dashboard') {
    sampleCountStatus = StatusItem();
    addStatusItem(sampleCountStatus);

    sampleFreqStatus = StatusItem();
    addStatusItem(sampleFreqStatus);
  }

  StatusItem sampleCountStatus;
  StatusItem sampleFreqStatus;

  PButton loadSnapshotButton;
  PButton resetButton;
  CoreElement progressElement;
  Table<PerfData> perfTable;

  CpuChart cpuChart;
  SetStateMixin cpuChartStateMixin = SetStateMixin();
  CpuTracker cpuTracker;

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
              loadSnapshotButton = PButton('Load snapshot')
                ..small()
                ..primary()
                ..click(_loadSnapshot),
              progressElement = span(c: 'margin-left text-gray')..flex(),
              resetButton = PButton('Reset VM counters')
                ..small()
                ..click(_reset),
            ])
        ]),
      _createTableView()..clazz('section'),
    ]);

    _updateStatus(null);

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

  void _handleIsolateChanged() {
    // TODO(devoncarew): Reset UI
  }

  String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

  void _loadSnapshot() {
    loadSnapshotButton.disabled = true;

    progressElement.text = 'Loading snapshot…';

    serviceManager.service
        .getCpuProfile(_isolateId, 'UserVM')
        .then((CpuProfile profile) async {
      final _CalcProfile calc = _CalcProfile(profile);
      await calc.calc();
      _updateStatus(profile);
    }).catchError((dynamic e) {
      framework.showError('Error loading snapshot', e);
    }).whenComplete(() {
      loadSnapshotButton.disabled = false;
      progressElement.text = '';
    });
  }

  CoreElement createLiveChartArea() {
    final CoreElement container = div(c: 'section perf-chart table-border')
      ..layoutVertical();
    cpuChart = CpuChart(container);
    cpuChart.disabled = true;
    return container;
  }

  void _reset() {
    resetButton.disabled = true;

    serviceManager.service.clearCpuProfile(_isolateId).then((_) {
      framework.toast('VM counters reset.');
    }).catchError((dynamic e) {
      framework.showError('Error resetting counters', e);
    }).whenComplete(() {
      resetButton.disabled = false;
    });
  }

  CoreElement _createTableView() {
    perfTable = Table<PerfData>.virtual();

    perfTable.addColumn(PerfColumnInclusive());
    perfTable.addColumn(PerfColumnSelf());
    perfTable.addColumn(PerfColumnMethodName());

    perfTable.sortColumn = perfTable.columns.first;

    perfTable.setRows(<PerfData>[]);

    perfTable.onSelect.listen((PerfData data) {
      // TODO(devoncarew): Handle item selection
      print(data);
    });

    return perfTable.element;
  }

  void _updateStatus(CpuProfile profile) {
    if (profile == null) {
      sampleCountStatus.element.text = '';
      sampleFreqStatus.element.text = '';
    } else {
      final Duration timeSpan = Duration(seconds: profile.timeSpan.round());
      String s = timeSpan.toString();
      s = s.substring(0, s.length - 7);
      sampleCountStatus.element.text =
          '${nf.format(profile.sampleCount)} samples over $s';
      sampleFreqStatus.element.text =
          '${profile.stackDepth} frames per sample @ ${profile.samplePeriod}Hz';

      _process(profile);
    }
  }

  void _process(CpuProfile profile) {
    perfTable.setRows(
        List<PerfData>.from(profile.functions.where((ProfileFunction f) {
      return f.inclusiveTicks > 0 || f.exclusiveTicks > 0;
    }).map<PerfData>((ProfileFunction f) {
      final int count = math.max(1, profile.sampleCount);
      return PerfData(
        f.kind,
        escape(funcRefName(f.function)),
        f.exclusiveTicks / count,
        f.inclusiveTicks / count,
      );
    })));
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    cpuChart.disabled = false;

    cpuTracker = CpuTracker(service);
    cpuTracker.start();

    cpuTracker.onChange.listen((Null _) {
      cpuChartStateMixin.setState(() {
        cpuChart.updateFrom(cpuTracker);
      });
    });
  }

  void _handleConnectionStop(dynamic event) {
    cpuChart.disabled = true;

    cpuTracker?.stop();
  }
}

class CpuChart extends LineChart<CpuTracker> {
  CpuChart(CoreElement parent) : super(parent, classes: 'perf-chart') {
    usageLabel = parent.add(div(c: 'perf-label'));
    usageLabel.element.style.right = '0';
  }

  CoreElement usageLabel;

  @override
  void update(CpuTracker data) {
    if (data.samples.isEmpty || dim == null) {
      return;
    }

    // display the cpu usage
    usageLabel.text = '${data._lastValue}%';

    // re-render the svg
    final int hRange = CpuTracker.kMaxGraphTime.inSeconds;
    const int vRange = 100;

    chartElement.setInnerHtml('''
<svg viewBox="0 0 0 0 ${dim.x} ${LineChart.fixedHeight}">
<polyline
    fill="none"
    stroke="#0074d9"
    stroke-width="3"
    points="${createPoints(data.samples, hRange, vRange)}"/>
</svg>
''');
  }

  String createPoints(List<int> samples, int hRange, int vRange) {
    // 0,120 20,60 40,80 60,20
    final List<String> coords = <String>[];
    int pos = 0;
    for (int i = samples.length - 1; i >= 0; i--) {
      final int x = dim.x - (pos * dim.x ~/ hRange);
      final int y = dim.y - (samples[i] * dim.y ~/ vRange);
      coords.add('$x,$y');
      pos++;
    }
    return coords.join(' ');
  }
}

class CpuTracker {
  CpuTracker(this.service);

  static const Duration kMaxGraphTime = Duration(minutes: 1);
  static const Duration kUpdateDelay = Duration(seconds: 1);

  VmServiceWrapper service;
  Timer _pollingTimer;
  final StreamController<Null> _changeController =
      StreamController<Null>.broadcast();
  List<int> samples = <int>[];

  bool get hasConnection => service != null;

  Stream<Null> get onChange => _changeController.stream;

  void start() {
    _pollingTimer = Timer(const Duration(milliseconds: 100), _pollCpu);
  }

  void _pollCpu() {
    if (!hasConnection) {
      return;
    }

    // TODO(devoncarew): Poll the VM for the CPU load.

    _pollingTimer = Timer(kUpdateDelay, _pollCpu);
  }

  void stop() {
    _pollingTimer?.cancel();
    service = null;
  }

  int get _lastValue => samples.isEmpty ? null : samples.last;

  // ignore: unused_element
  void _addSample(int sample) {
    samples.add(sample);

    while (samples.length > (kMaxGraphTime.inSeconds + 2)) {
      samples.removeAt(0);
    }

    _changeController.add(null);
  }
}

class PerfData {
  PerfData(this.kind, this.name, this.self, this.inclusive);

  final String kind;
  final String name;
  final double self;
  final double inclusive;

  @override
  String toString() => '[$kind] $name';
}

class PerfColumnInclusive extends Column<PerfData> {
  PerfColumnInclusive() : super('Total');

  @override
  bool get numeric => true;

  @override
  dynamic getValue(PerfData dataObject) => dataObject.inclusive;

  @override
  String render(dynamic value) => percent2(value);
}

class PerfColumnSelf extends Column<PerfData> {
  PerfColumnSelf() : super('Self');

  @override
  bool get numeric => true;

  @override
  dynamic getValue(PerfData dataObject) => dataObject.self;

  @override
  String render(dynamic value) => percent2(value);
}

class PerfColumnMethodName extends Column<PerfData> {
  PerfColumnMethodName() : super.wide('Method');

  @override
  bool get usesHtml => true;

  @override
  dynamic getValue(PerfData dataObject) {
    if (dataObject.kind == 'Dart') {
      return dataObject.name;
    }
    return '${dataObject.name} <span class="function-kind ${dataObject.kind}">${dataObject.kind}</span>';
  }
}

class _CalcProfile {
  _CalcProfile(this.profile);

  final CpuProfile profile;

  Future<void> calc() async {
    // TODO(devoncarew): Implement code to parse trie graph
    //profile.exclusiveCodeTrie;

//    tries['exclusiveCodeTrie'] =
//      new Uint32List.fromList(profile['exclusiveCodeTrie']);
//    tries['inclusiveCodeTrie'] =
//      new Uint32List.fromList(profile['inclusiveCodeTrie']);
//    tries['exclusiveFunctionTrie'] =
//      new Uint32List.fromList(profile['exclusiveFunctionTrie']);
//    tries['inclusiveFunctionTrie'] =
//      new Uint32List.fromList(profile['inclusiveFunctionTrie']);
  }
}

/*
// Process code table.
for (var codeRegion in profile['codes']) {
  if (needToUpdate()) {
    await signal(count * 100.0 / length);
  }
  Code code = codeRegion['code'];
  assert(code != null);
  codes.add(new ProfileCode.fromMap(this, code, codeRegion));
}
// Process function table.
for (var profileFunction in profile['functions']) {
  if (needToUpdate()) {
    await signal(count * 100 / length);
  }
  ServiceFunction function = profileFunction['function'];
  assert(function != null);
  functions.add(
      new ProfileFunction.fromMap(this, function, profileFunction));
}

tries['exclusiveCodeTrie'] =
    new Uint32List.fromList(profile['exclusiveCodeTrie']);
tries['inclusiveCodeTrie'] =
    new Uint32List.fromList(profile['inclusiveCodeTrie']);
tries['exclusiveFunctionTrie'] =
    new Uint32List.fromList(profile['exclusiveFunctionTrie']);
tries['inclusiveFunctionTrie'] =
    new Uint32List.fromList(profile['inclusiveFunctionTrie']);

*/
