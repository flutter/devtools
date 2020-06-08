// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../globals.dart';
import '../../storage.dart';
import '../logger/logger.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // When running in a desktop embedder, Flutter throws an error because the
  // platform is not officially supported. This is not needed for web.
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  setGlobal(Storage, FlutterDesktopStorage());

  return '';
}

class FlutterDesktopStorage implements Storage {
  Map<String, dynamic> _values;

  @override
  Future<String> getValue(String key) async {
    _values ??= _readValues();
    return _values[key];
  }

  @override
  Future setValue(String key, String value) async {
    try {
      _values = _readValues();
    } catch (e, st) {
      // ignore the error reading
      log('$e\n$st');

      _values = {};
    }

    _values[key] = value;

    const encoder = JsonEncoder.withIndent('  ');
    _preferencesFile.writeAsStringSync('${encoder.convert(_values)}\n');
  }

  Map<String, dynamic> _readValues() {
    final File file = _preferencesFile;
    if (file.existsSync()) {
      return jsonDecode(file.readAsStringSync());
    } else {
      return {};
    }
  }

  static File get _preferencesFile =>
      File(path.join(_userHomeDir(), '.devtools'));

  static String _userHomeDir() {
    final String envKey =
        Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    final String value = Platform.environment[envKey];
    return value == null ? '.' : value;
  }
}
