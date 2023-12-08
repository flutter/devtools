// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:web_benchmarks/client.dart';

import 'common.dart';
import 'devtools_recorder.dart';

typedef RecorderFactory = Recorder Function();

final Map<String, RecorderFactory> benchmarks = <String, RecorderFactory>{
  DevToolsBenchmark.navigateThroughOfflineScreens.id: () => DevToolsRecorder(
        benchmark: DevToolsBenchmark.navigateThroughOfflineScreens,
      ),
  DevToolsBenchmark.offlinePerformanceScreen.id: () => DevToolsRecorder(
        benchmark: DevToolsBenchmark.offlinePerformanceScreen,
      ),
};

/// Runs the client of the DevTools web benchmarks.
///
/// When the DevTools web benchmarks are run, the server builds an app with this
/// file as the entry point (see `run_benchmarks.dart`). The app automates
/// the DevTools web app, records some performance data, and reports them.
Future<void> main() async {
  await runBenchmarks(benchmarks, initialPage: benchmarkInitialPage);
}
