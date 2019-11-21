// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chrome.dart';

const verbose = true;

// TODO(dantup): Remove this when the live Pub version supports devTools.launch.
final bool serverDevToolsLaunchViaStdin =
    Platform.environment['USE_LOCAL_DEPENDENCIES'] == 'true';

class DevToolsServerDriver {
  DevToolsServerDriver._(this._process, this._stdin, Stream<String> _stdout,
      Stream<String> _stderr)
      : stdout = _stdout.map((line) {
          _trace('<== $line');
          return line;
        }).map((line) => jsonDecode(line) as Map<String, dynamic>),
        stderr = _stderr.map((line) {
          _trace('<== STDERR $line');
          return line;
        });

  final Process _process;
  final Stream<Map<String, dynamic>> stdout;
  final Stream<String> stderr;
  final StringSink _stdin;

  void write(Map<String, dynamic> request) {
    final line = jsonEncode(request);
    _trace('==> $line');
    _stdin.writeln(line);
  }

  static void _trace(String message) {
    if (verbose) {
      print(message);
    }
  }

  bool kill() => _process.kill();

  static Future<DevToolsServerDriver> create({
    int port = 0,
    int tryPorts,
  }) async {
    // These tests assume that the devtools package is present in a sibling
    // directory of the devtools_app package.
    final args = [
      '../devtools/bin/devtools.dart',
      '--machine',
      '--port',
      '$port',
    ];

    if (tryPorts != null) {
      args.addAll(['--try-ports', '$tryPorts']);
    }

    if (useChromeHeadless && headlessModeIsSupported) {
      args.add('--headless');
    }
    final Process process = await Process.start('dart', args);

    return DevToolsServerDriver._(
        process,
        process.stdin,
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
        process.stderr.transform(utf8.decoder).transform(const LineSplitter()));
  }
}
