// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Test arguments, defined inside the test file as a comment.
class InFileArgs {
  factory InFileArgs(String testFilePath) {
    final content = File(testFilePath).readAsStringSync();
    return InFileArgs.fromFileContent(content);
  }

  @visibleForTesting
  factory InFileArgs.fromFileContent(String fileContent) {
    final values = _parseFileContent(fileContent);

    for (final arg in values.keys) {
      values.putIfAbsent(arg, () => null);
    }

    return InFileArgs.fromValues(values);
  }

  @visibleForTesting
  InFileArgs.fromValues(Map<InFileArgItems, dynamic> values)
      : experimentsOn = values[InFileArgItems.experimentsOn] ?? false,
        appPath = values[InFileArgItems.appPath] ??
            'test/test_infra/fixtures/flutter_app';

  final bool experimentsOn;
  final String appPath;
}

const _argPrefix = '// test-argument:';

Map<InFileArgItems, dynamic> _parseFileContent(String fileContent) {
  final lines = fileContent
      .split('\n')
      .where((line) => line.startsWith(_argPrefix))
      .map((line) => line.substring(_argPrefix.length));

  return Map.fromEntries(lines.map((line) => _parseLine(line)));
}

MapEntry<InFileArgItems, dynamic> _parseLine(String line) {
  final nameValue = line.split('=');

  if (nameValue.length != 2) throw '[$line] does not match pattern name=value.';

  final name = nameValue[0];
  final value = nameValue[1];

  return MapEntry(InFileArgItems.values.byName(name), jsonDecode(value));
}

@visibleForTesting
enum InFileArgItems {
  experimentsOn,
  appPath,
}
