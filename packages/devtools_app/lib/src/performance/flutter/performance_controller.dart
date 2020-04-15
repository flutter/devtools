// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

import '../../flutter/controllers.dart';
import '../../globals.dart';
import '../../profiler/cpu_profile_controller.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../ui/fake_flutter/fake_flutter.dart';
import '../../utils.dart';

class PerformanceControllerProvider extends ControllerProvider {
  const PerformanceControllerProvider({Key key, Widget child})
      : super(key: key, child: child);

  @override
  _PerformanceControllerProviderState createState() =>
      _PerformanceControllerProviderState();

  static PerformanceController of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_InheritedPerformanceController>();
    return provider?.data;
  }
}

class _PerformanceControllerProviderState
    extends State<PerformanceControllerProvider> {
  PerformanceController data;

  @override
  void initState() {
    super.initState();
    // Everything depends on the serviceManager being available.
    assert(serviceManager != null);

    _initializeProviderData();
  }

  @override
  void didUpdateWidget(PerformanceControllerProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeProviderData();
  }

  void _initializeProviderData() {
    data = PerformanceController();
  }

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedPerformanceController(data: data, child: widget.child);
  }
}

class _InheritedPerformanceController extends InheritedWidget {
  const _InheritedPerformanceController(
      {@required this.data, @required Widget child})
      : super(child: child);

  final PerformanceController data;

  @override
  bool updateShouldNotify(_InheritedPerformanceController oldWidget) =>
      oldWidget.data != data;
}

class PerformanceController with CpuProfilerControllerProviderMixin {
  CpuProfileData get cpuProfileData => cpuProfilerController.dataNotifier.value;

  /// Notifies that a CPU profile is currently being recorded.
  ValueListenable get recordingNotifier => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  final int _profileStartMicros = 0;

  Future<void> startRecording() async {
    await clear();
    _recordingNotifier.value = true;
  }

  Future<void> stopRecording() async {
    _recordingNotifier.value = false;
    await cpuProfilerController.pullAndProcessProfile(
      startMicros: _profileStartMicros,
      // Using [maxJsInt] as [extentMicros] for the getCpuProfile requests will
      // give us all cpu samples we have available
      extentMicros: maxJsInt,
    );
  }

  Future<void> clear() async {
    await cpuProfilerController.clear();
  }

  void dispose() {
    _recordingNotifier.dispose();
    cpuProfilerController.dispose();
  }
}
