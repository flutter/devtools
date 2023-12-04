// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:web_benchmarks/server.dart';

import 'test_infra/project_root_directory.dart';

/// Runs the DevTools web benchmarks and reports the benchmark data.
Future<void> main() async {
  stdout.writeln('Starting web benchmark tests ...');

  final taskResult = await serveWebBenchmark(
    benchmarkAppDirectory: projectRootDirectory(),
    entryPoint: 'test_benchmarks/test_infra/client.dart',
    useCanvasKit: true,
    treeShakeIcons: false,
    headless: false,
    // Pass an empty initial page so that the benchmark server does not attempt
    // to load the default page 'index.html', which will show up as "page not
    // found" in DevTools.
    initialPage: '',
  );

  stdout.writeln('Web benchmark tests finished.');

  stdout.writeln('==== Results ====');

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(taskResult.toJson()),
  );

  stdout.writeln('==== End of results ====');
}
