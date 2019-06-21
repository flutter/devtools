// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/ui/html_icon_renderer.dart';
import 'package:meta/meta.dart';

import '../framework/framework.dart';
import '../profiler/cpu_profile_flame_chart.dart';
import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profile_tables.dart';
import '../profiler/cpu_profiler.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/html_icon_renderer.dart';
import '../ui/icons.dart';
import '../ui/material_icons.dart';
import '../ui/primer.dart';
import '../ui/theme.dart';
import 'performance_controller.dart';

const Icon record = MaterialIcon(
  'fiber_manual_record',
  defaultPrimaryButtonIconColor,
);

const Icon instructionsRecord = MaterialIcon(
  'fiber_manual_record',
  defaultButtonIconColor,
);

const Icon stop = MaterialIcon('stop', defaultButtonIconColor);

class PerformanceScreen extends Screen {
  PerformanceScreen()
      : super(
            name: 'Performance',
            id: 'performance',
            iconClass: 'octicon-dashboard');

  PerformanceController performanceController = PerformanceController();

  PButton startRecordingButton;

  PButton stopRecordingButton;

  PButton clearButton;

  CoreElement profilingInstructions;

  CoreElement recordingMessage;

  CpuProfilerTabNav tabNav;

  _CpuProfiler cpuProfiler;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div()..layoutVertical();

    // Initialize screen content.
    _initContent();

    screenDiv.add([
      div(c: 'section')
        ..layoutHorizontal()
        ..add([
          div(c: 'btn-group')
            ..add([
              startRecordingButton,
              stopRecordingButton,
            ]),
          clearButton,
        ]),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add([
          tabNav.element..hidden(true),
          div(c: 'profiler-container section-border')
            ..add(cpuProfiler..hidden(true)),
        ]),
      profilingInstructions,
      recordingMessage..hidden(true),
    ]);

    return screenDiv;
  }

  void _initContent() {
    startRecordingButton = PButton.icon('Record', record)
      ..small()
      ..primary()
      ..click(_startRecording);

    stopRecordingButton = PButton.icon('Stop', stop)
      ..small()
      ..clazz('margin-left')
      ..disabled = true
      ..click(_stopRecording);

    clearButton = PButton.icon('Clear', clearIcon)
      ..small()
      ..clazz('margin-left')
      ..setAttribute('title', 'Clear timeline')
      ..click(_clear);

    profilingInstructions = div(c: 'message')
      ..layoutVertical()
      ..flex()
      ..add([
        div(c: 'instruction-message')
          ..layoutHorizontal()
          ..flex()
          ..add([
            div(text: 'Click the record button '),
            createIconElement(instructionsRecord),
            div(text: 'to start recording a CPU profile.')
          ]),
        div(c: 'instruction-message')
          ..layoutHorizontal()
          ..flex()
          ..add([
            div(text: 'Click the stop button '),
            createIconElement(stop),
            div(text: 'to end the recording.')
          ]),
      ]);

    recordingMessage = div(c: 'message')
      ..layoutVertical()
      ..flex()
      ..add([
        div(text: 'Recording', c: 'recording-message'),
        Spinner.centered(),
      ]);

    cpuProfiler = _CpuProfiler(performanceController);

    tabNav = CpuProfilerTabNav(
      cpuProfiler,
      CpuProfilerTabOrder(
        first: CpuProfilerViewType.callTree,
        second: CpuProfilerViewType.bottomUp,
        third: CpuProfilerViewType.flameChart,
      ),
    );
  }

  void _startRecording() {
    performanceController.startRecording();
    _updateCpuProfilerVisibility(hidden: true);
    _updateButtonStates();
    profilingInstructions.hidden(true);
    recordingMessage.hidden(false);
  }

  void _stopRecording() async {
    performanceController.stopRecording();
    recordingMessage.hidden(true);
    _updateCpuProfilerVisibility(hidden: false);
    _updateButtonStates();
    await cpuProfiler.update();
  }

  void _clear() {
    performanceController.reset();
    _updateCpuProfilerVisibility(hidden: true);
    profilingInstructions.hidden(false);
  }

  void _updateButtonStates() {
    startRecordingButton.disabled = performanceController.recording;
    clearButton.disabled = performanceController.recording;
    stopRecordingButton.disabled = !performanceController.recording;
  }

  void _updateCpuProfilerVisibility({@required bool hidden}) {
    tabNav.element.hidden(hidden);
    cpuProfiler.hidden(hidden);
  }
}

class _CpuProfiler extends CpuProfiler {
  _CpuProfiler(this._performanceController)
      : super(
          _CpuFlameChart(_performanceController),
          _CpuCallTree(_performanceController),
          _CpuBottomUp(_performanceController),
          defaultView: CpuProfilerViewType.callTree,
        );

  final PerformanceController _performanceController;

  @override
  Future<void> prepareCpuProfile() async {
    _performanceController.mergeRecordedProfiles();
  }

  @override
  bool maybeShowMessageOnUpdate() {
    if (_performanceController.cpuProfileData == null) {
      showMessage(div(text: 'No CPU samples recorded.'));
      return true;
    }
    return false;
  }
}

class _CpuFlameChart extends CpuFlameChart {
  _CpuFlameChart(this._performanceController);

  PerformanceController _performanceController;

  @override
  CpuProfileData getProfileData() => _performanceController.cpuProfileData;
}

class _CpuCallTree extends CpuCallTree {
  _CpuCallTree(this._performanceController);

  PerformanceController _performanceController;

  @override
  CpuProfileData getProfileData() => _performanceController.cpuProfileData;
}

class _CpuBottomUp extends CpuBottomUp {
  _CpuBottomUp(this._performanceController);

  PerformanceController _performanceController;

  @override
  CpuProfileData getProfileData() => _performanceController.cpuProfileData;
}
