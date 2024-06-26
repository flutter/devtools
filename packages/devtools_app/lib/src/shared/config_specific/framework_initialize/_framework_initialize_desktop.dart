// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_app_shared/utils.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../../primitives/storage.dart';

final _log = Logger('_framework_initialize_desktop');

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  setGlobal(Storage, FlutterDesktopStorage());
  return '';
}

class FlutterDesktopStorage implements Storage {
  late final _values = _readValues();
  bool _fileAndDirVerified = false;

  @override
  Future<String?> getValue(String key) async {
    return _values[key] as String?;
  }

  @override
  Future setValue(String key, String value) async {
    _values[key] = value;

    const encoder = JsonEncoder.withIndent('  ');
    if (!_fileAndDirVerified) {
      File(_preferencesFile.path).createSync(recursive: true);
      _fileAndDirVerified = true;
    }
    _preferencesFile.writeAsStringSync('${encoder.convert(_values)}\n');
  }

  Map<String, Object?> _readValues() {
    final file = _preferencesFile;
    try {
      if (file.existsSync()) {
        return jsonDecode(file.readAsStringSync()) ?? {};
      } else {
        return {};
      }
    } catch (e, st) {
      // ignore the error reading
      _log.info(e, e, st);
      return {};
    }
  }

  static File get _preferencesFile =>
      File(path.join(_userHomeDir(), '.flutter-devtools/.devtools'));

  static String _userHomeDir() {
    final envKey = Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    final value = Platform.environment[envKey];
    return value ?? '.';
  }
}
