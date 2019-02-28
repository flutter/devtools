// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Check that the pubspec version and the devtools application version are in
/// sync.

import 'dart:io';

import 'package:devtools/devtools.dart' as devtools show version;

void main() {
  final File pubspecFile = new File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    fail('${pubspecFile.path} not found.');
  }

  final String versionString = pubspecFile
      .readAsLinesSync()
      .firstWhere((line) => line.startsWith('version:'));

  final String pubspecVersion =
      versionString.substring('version:'.length).trim();

  if (pubspecVersion != devtools.version) {
    fail('App version ${devtools.version} != pubspec version $pubspecVersion; '
        'these need to be kept in sync.');
  }

  print('DevTools version ${devtools.version}.');
}

void fail(String message) {
  stderr.writeln(message);
  exit(1);
}
