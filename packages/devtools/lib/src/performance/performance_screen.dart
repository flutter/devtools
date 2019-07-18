// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:meta/meta.dart';

import '../framework/framework.dart';
import '../profiler/cpu_profile_flame_chart.dart';
import '../profiler/cpu_profile_tables.dart';
import '../profiler/cpu_profiler.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/html_icon_renderer.dart';
import '../ui/material_icons.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../ui/vm_flag_elements.dart';
import 'performance_controller.dart';

const performanceScreenId = 'performance';

class PerformanceScreen extends Screen {
  PerformanceScreen()
      : super(
            name: 'Performance',
            id: 'performance',
            iconClass: 'octicon-dashboard');

  final PerformanceController _performanceController = PerformanceController();

  PButton _startRecordingButton;

  PButton _stopRecordingButton;

  PButton _clearButton;

  ProfileGranularitySelector _profileGranularitySelector;

  CoreElement _profilerInstructions;

  CoreElement _profilerStatus;

  CoreElement _profilerStatusMessage;

  CpuProfilerTabNav _tabNav;

  _CpuProfiler _cpuProfiler;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    // Initialize screen content.
    _initContent();

    screenDiv.add([
      div(c: 'section')
        ..layoutHorizontal()
        ..add([
          div(c: 'btn-group')
            ..add([
              _startRecordingButton,
              _stopRecordingButton,
            ]),
          _clearButton,
          div()..flex(),
          _profileGranularitySelector.selector,
        ]),
      div(c: 'section')
        ..layoutVertical()
        ..flex()
        ..add([
          _tabNav.element..hidden(true),
          div(c: 'profiler-container section-border')
            ..add([
              _cpuProfiler..hidden(true),
              _profilerInstructions,
              _profilerStatus..hidden(true)
            ]),
        ]),
    ]);

    maybeAddDebugMessage(framework, performanceScreenId);

    return screenDiv;
  }

  void _initContent() {
    _startRecordingButton = PButton.icon('Record', recordPrimary)
      ..small()
      ..primary()
      ..click(() async => await _startRecording());

    _stopRecordingButton = PButton.icon('Stop', stop)
      ..small()
      ..clazz('margin-left')
      ..disabled = true
      ..click(() async => await _stopRecording());

    _clearButton = PButton.icon('Clear', clearIcon)
      ..small()
      ..clazz('margin-left')
      ..setAttribute('title', 'Clear timeline')
      ..click(_clear);

    _profileGranularitySelector = ProfileGranularitySelector(framework);

    _profilerInstructions = div(c: 'center-in-parent instruction-container')
      ..layoutVertical()
      ..flex()
      ..add([
        div(c: 'instruction-message')
          ..layoutHorizontal()
          ..flex()
          ..add([
            div(text: 'Click the record button '),
            createIconElement(record),
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

    _profilerStatus = div(c: 'center-in-parent')
      ..layoutVertical()
      ..flex()
      ..add([
        _profilerStatusMessage = div(c: 'profiler-status-message'),
        Spinner.centered(classes: ['profiler-spinner']),
      ]);

    _cpuProfiler = _CpuProfiler(
      _performanceController,
      () => _performanceController.cpuProfileData,
    );

    _tabNav = CpuProfilerTabNav(
      _cpuProfiler,
      CpuProfilerTabOrder(
        first: CpuProfilerViewType.callTree,
        second: CpuProfilerViewType.bottomUp,
        third: CpuProfilerViewType.flameChart,
      ),
    );
  }

  @override
  void entering() {
    _profileGranularitySelector.setGranularity();
  }

  Future<void> _startRecording() async {
    await _performanceController.startRecording();
    _updateCpuProfilerVisibility(hidden: true);
    _updateButtonStates();
    _profilerInstructions.hidden(true);
    _profilerStatusMessage.text = 'Recording profile';
    _profilerStatus.hidden(false);
  }

  Future<void> _stopRecording() async {
    _profilerStatusMessage.text = 'Processing profile';
    await _performanceController.stopRecording();
    _profilerStatus.hidden(true);
    _updateCpuProfilerVisibility(hidden: false);
    _updateButtonStates();
    await _cpuProfiler.update();
  }

  void _clear() {
    _performanceController.reset();
    _updateCpuProfilerVisibility(hidden: true);
    _profilerInstructions.hidden(false);
  }

  void _updateButtonStates() {
    _startRecordingButton.disabled = _performanceController.recording;
    _clearButton.disabled = _performanceController.recording;
    _stopRecordingButton.disabled = !_performanceController.recording;
  }

  void _updateCpuProfilerVisibility({@required bool hidden}) {
    _tabNav.element.hidden(hidden);
    _cpuProfiler.hidden(hidden);
  }
}

class _CpuProfiler extends CpuProfiler {
  _CpuProfiler(
    this._performanceController,
    CpuProfileDataProvider profileDataProvider,
  ) : super(
          CpuFlameChart(profileDataProvider),
          CpuCallTree(profileDataProvider),
          CpuBottomUp(profileDataProvider),
          defaultView: CpuProfilerViewType.callTree,
        );

  final PerformanceController _performanceController;

  @override
  Future<void> prepareCpuProfile() async {
    _performanceController.cpuProfileTransformer
        .processData(_performanceController.cpuProfileData);
  }

  @override
  bool maybeShowMessageOnUpdate() {
    if (_performanceController.cpuProfileData == null ||
        _performanceController.cpuProfileData.sampleCount == 0) {
      showMessage(div(text: 'No CPU samples recorded.'));
      return true;
    }
    return false;
  }
}
