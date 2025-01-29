// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:web_benchmarks/client.dart';

import '../common.dart';
import 'client_shared.dart';

/// Runs the client of the DevTools web benchmarks.
///
/// When the DevTools web benchmarks are run, the server builds an app with this
/// file as the entry point (see `run_benchmarks.dart`). The app automates
/// the DevTools web app, records some performance data, and reports them.
Future<void> main() async {
  await runBenchmarks(benchmarks, benchmarkPath: benchmarkPath(useWasm: false));
}
