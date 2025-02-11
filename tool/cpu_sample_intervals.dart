// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

/// Outputs the time intervals between adjacent cpu samples.
///
/// A json file path is required as a command line argument.
/// Ex: dart cpu_sample_intervals.dart ~/Downloads/example_json.dart
void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      'You must specify a json input file path.\n'
      'Ex: dart cpu_sample_intervals.dart ~/Downloads/example.json',
    );
    return;
  }

  final File file = File(arguments.first);
  final Map<String, dynamic> timelineDump =
      (jsonDecode(await file.readAsString()) as Map).cast<String, dynamic>();
  final List<dynamic> cpuSampleTraceEvents =
      timelineDump['cpuProfile']['traceEvents'] as List;

  final List<int> deltas = [];
  for (int i = 0; i < cpuSampleTraceEvents.length - 1; i++) {
    final Map<String, dynamic> current =
        (cpuSampleTraceEvents[i] as Map).cast<String, dynamic>();
    final Map<String, dynamic> next =
        (cpuSampleTraceEvents[i + 1] as Map).cast<String, dynamic>();
    deltas.add((next['ts'] as int) - (current['ts'] as int));
  }
  print(deltas);
}
