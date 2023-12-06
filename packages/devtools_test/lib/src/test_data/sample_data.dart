// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';

import 'performance.dart';

const performanceFileName = 'performance_data.json';

final sampleData = <DevToolsJsonFile>[
  DevToolsJsonFile(
    name: performanceFileName,
    lastModifiedTime: DateTime.now(),
    data: jsonDecode(jsonEncode(samplePerformanceData)),
  ),
];
