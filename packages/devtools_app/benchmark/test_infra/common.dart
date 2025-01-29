// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// The initial page to load upon opening the DevTools benchmark app or
/// reloading it in Chrome.
///
/// We use an empty initial page so that the benchmark server does not attempt
/// to load the default page 'index.html', which will show up as "page not
/// found" in DevTools.
const _benchmarkInitialPage = '';

const _wasmQueryParameters = {'wasm': 'true'};

String benchmarkPath({required bool useWasm}) =>
    Uri(
      path: _benchmarkInitialPage,
      queryParameters: useWasm ? _wasmQueryParameters : null,
    ).toString();

String generateBenchmarkEntryPoint({required bool useWasm}) {
  return 'benchmark/test_infra/client/client_${useWasm ? 'wasm' : 'js'}.dart';
}

const devtoolsBenchmarkPrefix = 'devtools';

enum DevToolsBenchmark {
  navigateThroughOfflineScreens,
  offlineCpuProfilerScreen,
  offlinePerformanceScreen;

  String get id => '${devtoolsBenchmarkPrefix}_$name';
}
