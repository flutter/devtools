// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';

const _dataDir = 'test/test_data/memory/leaks/';

class GoldenLeakTest {
  GoldenLeakTest({
    required this.name,
    required this.appClassName,
  });

  final String name;
  final String appClassName;

  String get pathForLeakDetails => '$_dataDir$name.yaml';

  Future<NotGCedAnalyzerTask> task() async {
    final path = '$_dataDir$name.raw.json';
    final json = jsonDecode(await File(path).readAsString());
    return NotGCedAnalyzerTask.fromJson(json);
  }
}

final goldenLeakTests = [
  GoldenLeakTest(
    name: 'leaking_demo_app',
    appClassName: 'MyApp',
  ),
];
