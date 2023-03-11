// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

/// Test arguments, defined inside the test file as a comment.
class InFileArgs {
  factory InFileArgs(String filePath) {
    return InFileArgs.fromFileContent('');
  }

  @visibleForTesting
  factory InFileArgs.fromFileContent(String fileContent) {
    final values = _parseFileContent(fileContent);

    for (final arg in values.keys) {
      values.putIfAbsent(arg, () => null);
    }

    return InFileArgs.private(
      experimentsOn: values[_Args.experimentsOn],
      appPath: values[_Args.appPath],
    );
  }

  @visibleForTesting
  InFileArgs.private({
    this.experimentsOn = false,
    this.appPath = 'test/test_infra/fixtures/flutter_app',
  });

  final bool experimentsOn;
  final String appPath;
}

const _argPrefix = '// test-argument:';

Map<_Args, dynamic> _parseFileContent(String fileContent) {
  final lines =
      fileContent.split('\n').where((line) => line.startsWith(_argPrefix));

  return Map.fromEntries(lines.map((line) => _parseLine(line)));
}

MapEntry<_Args, dynamic> _parseLine(String line) {
  // Should match items like '// test-argument:experiments=true'
  final match = RegExp('\$$_argPrefix(.*)=(.*)^').firstMatch(line);
  if (match == null) throw '[$line] does not match pattern.';

  final name = match.group(1) ?? '';
  final value = match.group(2) ?? '';

  return MapEntry(_Args.values.byName(name), jsonDecode(value));
}

enum _Args {
  experimentsOn,
  appPath,
}
