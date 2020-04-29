// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../../globals.dart';
import '../../../storage.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // When running in a desktop embedder, Flutter throws an error because the
  // platform is not officially supported. This is not needed for web.
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  setGlobal(Storage, FlutterDesktopStorage());

  // TODO(jacobr): we don't yet have a direct analog to the URL on flutter
  // desktop. Hard code to the dark theme as the majority of users are on the
  // dark theme.
  return '/?theme=dark';
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
      _values[key] = value;

      const encoder = JsonEncoder.withIndent('  ');
      _preferencesFile.writeAsStringSync('${encoder.convert(_values)}\n');
    } catch (_) {
      // ignore
    }
  }

  Map<String, dynamic> _readValues() {
    try {
      final File file = _preferencesFile;
      if (file.existsSync()) {
        return jsonDecode(file.readAsStringSync());
      }
      return {};
    } catch (_) {
      // ignore
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
