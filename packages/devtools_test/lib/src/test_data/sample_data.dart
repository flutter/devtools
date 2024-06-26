// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';

import '_cpu_profiler_data.dart';
import '_performance_data.dart';
import '_performance_data_large.dart';

// To create Dart test data files from JSON, use the `tool/json_to_map.dart`
// script.

const cpuProfilerFileName = 'cpu_profile_data.json';
const performanceFileName = 'performance_data.json';
const performanceLargeFileName = 'performance_large_data.json';

final sampleData = <DevToolsJsonFile>[
  DevToolsJsonFile(
    name: performanceFileName,
    lastModifiedTime: DateTime.now(),
    data: jsonDecode(jsonEncode(samplePerformanceData)),
  ),
  DevToolsJsonFile(
    name: performanceLargeFileName,
    lastModifiedTime: DateTime.now(),
    data: jsonDecode(jsonEncode(samplePerformanceDataLarge)),
  ),
  DevToolsJsonFile(
    name: cpuProfilerFileName,
    lastModifiedTime: DateTime.now(),
    data: jsonDecode(jsonEncode(sampleCpuProfilerData)),
  ),
];
