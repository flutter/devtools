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

class PerformanceScreen extends Screen {
  StatusItem sampleCountStatus;
  StatusItem sampleFreqStatus;

  PButton loadSnapshotButton;
  PButton resetButton;
  CoreElement progressElement;
  Table<PerfData> perfTable;
  Framework framework;

  CpuChart cpuChart;
  SetStateMixin cpuChartStateMixin = new SetStateMixin();
  CpuTracker cpuTracker;

  PerformanceScreen()
      : super('Performance', 'performance', 'octicon-dashboard') {
    sampleCountStatus = new StatusItem();
    addStatusItem(sampleCountStatus);

    sampleFreqStatus = new StatusItem();
    addStatusItem(sampleFreqStatus);
  }

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    this.framework = framework;

    mainDiv.add([
      createLiveChartArea(),
      div(c: 'section'),
      div(c: 'section')
        ..add([
          form()
            ..layoutHorizontal()
            ..clazz('align-items-center')
            ..add([
              loadSnapshotButton = new PButton('Load snapshot')
                ..small()
                ..primary()
                ..click(_loadSnapshot),
              progressElement = span(c: 'margin-left text-gray')..flex(),
              resetButton = new PButton('Reset VM counters')
                ..small()
                ..click(_reset),
            ])
        ]),
      _createTableView()..clazz('section'),
    ]);

    _updateStatus(null);

    serviceInfo.isolateManager.onSelectedIsolateChanged.listen((_) {
      _handleIsolateChanged();
    });

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceInfo.hasConnection) {
      _handleConnectionStart(serviceInfo.service);
    }
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);
  }

  void _handleIsolateChanged() {
    // TODO: update buttons
  }

  String get _isolateId => serviceInfo.isolateManager.selectedIsolate.id;

  void _loadSnapshot() {
    loadSnapshotButton.disabled = true;

    progressElement.text = 'Loading snapshot…';

    serviceInfo.service
        .getCpuProfile(_isolateId, 'UserVM')
        .then((CpuProfile profile) async {
      // TODO:
      print(profile);

      _CalcProfile calc = new _CalcProfile(profile);
      await calc.calc();

      _updateStatus(profile);
    }).catchError((e) {
      framework.showError('', e);
    }).whenComplete(() {
      loadSnapshotButton.disabled = false;
      progressElement.text = '';
    });
  }

  CoreElement createLiveChartArea() {
    CoreElement container = div(c: 'section perf-chart table-border')
      ..layoutVertical();
    cpuChart = new CpuChart(container);
    cpuChart.disabled = true;
    return container;
  }

  void _reset() {
    resetButton.disabled = true;

    serviceInfo.service.clearCpuProfile(_isolateId).then((_) {
      toast('VM counters reset.');
    }).catchError((e) {
      framework.showError('Error resetting counters', e);
    }).whenComplete(() {
      resetButton.disabled = false;
    });
  }

  CoreElement _createTableView() {
    perfTable = new Table<PerfData>();

    perfTable.addColumn(new PerfColumnInclusive());
    perfTable.addColumn(new PerfColumnSelf());
    perfTable.addColumn(new PerfColumnMethodName());

    perfTable.setSortColumn(perfTable.columns.first);

    perfTable.setRows(new List<PerfData>());

    perfTable.onSelect.listen((PerfData data) {
      // TODO:
      print(data);
    });

    return perfTable.element;
  }

  void _updateStatus(CpuProfile profile) {
    if (profile == null) {
      sampleCountStatus.element.text = '';
      sampleFreqStatus.element.text = '';
    } else {
      Duration timeSpan = new Duration(seconds: profile.timeSpan.round());
      String s = timeSpan.toString();
      s = s.substring(0, s.length - 7);
      sampleCountStatus.element.text =
          '${nf.format(profile.sampleCount)} samples over $s';
      sampleFreqStatus.element.text =
          '${profile.stackDepth} frames per sample @ ${profile.samplePeriod}Hz';

      _process(profile);
    }
  }

  HelpInfo get helpInfo =>
      new HelpInfo('performance view docs', 'http://www.cheese.com');

  void _process(CpuProfile profile) {
    perfTable.setRows(
        new List<PerfData>.from(profile.functions.where((ProfileFunction f) {
      return f.inclusiveTicks > 0 || f.exclusiveTicks > 0;
    }).map((ProfileFunction f) {
      int count = math.max(1, profile.sampleCount);
      return new PerfData(
        f.kind,
        escape(funcRefName(f.function)),
        f.exclusiveTicks / count,
        f.inclusiveTicks / count,
      );
    })));
  }

  void _handleConnectionStart(VmService service) {
    cpuChart.disabled = false;

    cpuTracker = new CpuTracker(service);
    cpuTracker.start();

    cpuTracker.onChange.listen((_) {
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
  CoreElement usageLabel;

  CpuChart(CoreElement parent) : super(parent) {
    usageLabel = parent.add(div(c: 'perf-label'));
    usageLabel.element.style.right = '0';
  }

  void update(CpuTracker tracker) {
    if (tracker.samples.isEmpty || dim == null) {
      // TODO:
      return;
    }

    // display the cpu usage
    usageLabel.text = '${tracker._lastValue}%';

    // re-render the svg
    final int hRange = CpuTracker.kMaxGraphTime.inSeconds;
    const int vRange = 100;

    chartElement.setInnerHtml('''
<svg viewBox="0 0 0 0 ${dim.x} ${dim.y}">
<polyline
    fill="none"
    stroke="#0074d9"
    stroke-width="3"
    points="${createPoints(tracker.samples, hRange, vRange)}"/>
</svg>
''');
  }

  String createPoints(List<int> samples, int hRange, int vRange) {
    // 0,120 20,60 40,80 60,20
    List<String> coords = [];
    int pos = 0;
    for (int i = samples.length - 1; i >= 0; i--) {
      final int x = dim.x - (pos * dim.x ~/ hRange);
      final int y = dim.y - (samples[i] * dim.y ~/ vRange);
      coords.add('${x},${y}');
      pos++;
    }
    return coords.join(' ');
  }
}

class CpuTracker {
  static const Duration kMaxGraphTime = const Duration(minutes: 1);
  static const Duration kUpdateDelay = const Duration(seconds: 1);

  static final math.Random rnd = new math.Random();

  VmService service;
  Timer _pollingTimer;
  final StreamController _changeController = new StreamController.broadcast();
  List<int> samples = [];

  CpuTracker(this.service);

  bool get hasConnection => service != null;

  Stream get onChange => _changeController.stream;

  void start() {
    _pollingTimer = new Timer(const Duration(milliseconds: 100), _pollCpu);
  }

  void _pollCpu() {
    if (!hasConnection) return;

    _addSample(clamp((_lastValue ?? 50) + rnd.nextInt(20) - 10, 0, 100));

    _pollingTimer = new Timer(kUpdateDelay, _pollCpu);
  }

  void stop() {
    _pollingTimer?.cancel();
    service = null;
  }

  int get _lastValue => samples.isEmpty ? null : samples.last;

  void _addSample(int sample) {
    samples.add(sample);

    while (samples.length > (kMaxGraphTime.inSeconds + 2)) {
      samples.removeAt(0);
    }

    _changeController.add(null);
  }
}

class PerfData {
  final String kind;
  final String name;
  final double self;
  final double inclusive;

  PerfData(this.kind, this.name, this.self, this.inclusive);

  String toString() => '[$kind] $name';
}

class PerfColumnInclusive extends Column<PerfData> {
  PerfColumnInclusive() : super('Total');

  bool get numeric => true;

  //String get cssClass => 'monospace';

  dynamic getValue(PerfData row) => row.inclusive;

  String render(dynamic value) => percent2(value);
}

class PerfColumnSelf extends Column<PerfData> {
  PerfColumnSelf() : super('Self');

  bool get numeric => true;

  //String get cssClass => 'monospace';

  dynamic getValue(PerfData row) => row.self;

  String render(dynamic value) => percent2(value);
}

class PerfColumnMethodName extends Column<PerfData> {
  PerfColumnMethodName() : super('Method', wide: true);

  bool get usesHtml => true;

  dynamic getValue(PerfData row) {
    if (row.kind == 'Dart') {
      return row.name;
    }
    return '${row.name} <span class="function-kind ${row.kind}">${row.kind}</span>';
  }
}

class _CalcProfile {
  final CpuProfile profile;

  _CalcProfile(this.profile);

  Future calc() async {
    // TODO:
    profile.exclusiveCodeTrie;

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

int clamp(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
