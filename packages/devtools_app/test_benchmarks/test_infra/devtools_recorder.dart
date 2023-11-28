// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/initialization.dart';
import 'package:flutter/material.dart';
import 'package:web_benchmarks/client.dart';

import 'devtools_automator.dart';

/// A recorder that measures frame building durations for the DevTools.
class DevToolsRecorder extends WidgetRecorder {
  DevToolsRecorder({required this.benchmarkName})
      : super(name: benchmarkName, useCustomWarmUp: true);

  /// The name of the DevTools benchmark to be run.
  ///
  /// See `common.dart` for the list of the names of all benchmarks.
  final String benchmarkName;

  DevToolsAutomater? _devToolsAutomator;
  bool get _finished => _devToolsAutomator?.finished ?? false;

  /// Whether we should continue recording.
  @override
  bool shouldContinue() => !_finished || profile.shouldContinue();

  /// Creates the [DevToolsAutomater] widget.
  @override
  Widget createWidget() {
    _devToolsAutomator = DevToolsAutomater(
      benchmarkName: benchmarkName,
      stopWarmingUpCallback: profile.stopWarmingUp,
    );
    return _devToolsAutomator!.createWidget();
  }

  @override
  Future<Profile> run() async {
    // ignore: invalid_use_of_visible_for_testing_member, valid use for benchmark tests.
    await initializeDevTools();
    return super.run();
  }
}
