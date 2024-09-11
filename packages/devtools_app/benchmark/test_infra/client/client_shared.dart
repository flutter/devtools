// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:web_benchmarks/client.dart';

import '../common.dart';
import '../devtools_recorder.dart';

typedef RecorderFactory = Recorder Function();

final benchmarks = <String, RecorderFactory>{
  DevToolsBenchmark.navigateThroughOfflineScreens.id: () => DevToolsRecorder(
        benchmark: DevToolsBenchmark.navigateThroughOfflineScreens,
      ),
  DevToolsBenchmark.offlineCpuProfilerScreen.id: () => DevToolsRecorder(
        benchmark: DevToolsBenchmark.offlineCpuProfilerScreen,
      ),
  DevToolsBenchmark.offlinePerformanceScreen.id: () => DevToolsRecorder(
        benchmark: DevToolsBenchmark.offlinePerformanceScreen,
      ),
};
