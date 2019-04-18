// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Check that devtools/analysis_options.yaml and
/// devtools_server/analysis_options.yaml are identical.

import 'dart:io';

void main() {
  final File devToolsOptions = File('../devtools/analysis_options.yaml');
  if (!devToolsOptions.existsSync()) {
    fail('${devToolsOptions.path} not found.');
  }

  final File devToolsServerOptions =
      new File('../devtools_server/analysis_options.yaml');
  if (!devToolsServerOptions.existsSync()) {
    fail('${devToolsServerOptions.path} not found.');
  }

  final devToolsOptionsContent = devToolsOptions.readAsLinesSync();
  final devToolsServerOptionsContent = devToolsServerOptions.readAsLinesSync();

  for (int i = 0; i < devToolsOptionsContent.length; i++) {
    final devToolsLine = devToolsOptionsContent[i];
    final devToolsServerLine = devToolsServerOptionsContent[i];
    if (devToolsLine != devToolsServerLine) {
      fail(
        'devtools/analysis_options.yaml is not identical to '
        'devtools_server/analysis_options.yaml.\n'
        '$devToolsLine (devtools/analysis_options.yaml:${i + 1})\n'
        '$devToolsServerLine (devtools_server/analysis_options.yaml:${i + 1})',
      );
    }
  }
}

void fail(String message) {
  stderr.writeln(message);
  exit(1);
}
