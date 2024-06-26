// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The initial page to load upon opening the DevTools benchmark app or
/// reloading it in Chrome.
//
// We use an empty initial page so that the benchmark server does not attempt
// to load the default page 'index.html', which will show up as "page not
// found" in DevTools.
const benchmarkInitialPage = '';

const devtoolsBenchmarkPrefix = 'devtools';

enum DevToolsBenchmark {
  navigateThroughOfflineScreens,
  offlineCpuProfilerScreen,
  offlinePerformanceScreen;

  String get id => '${devtoolsBenchmarkPrefix}_$name';
}
