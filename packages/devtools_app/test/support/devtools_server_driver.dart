// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const verbose = true;

class DevToolsServerDriver {
  DevToolsServerDriver._(
      this._process, this._stdin, Stream<String> _stdout, this.stderr)
      : output = _stdout.map((line) {
          _trace('<== $line');
          return line;
        }).map((line) => jsonDecode(line) as Map<String, dynamic>);

  final Process _process;
  final Stream<Map<String, dynamic>> output;
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

    // TODO: This needs enabling once the server version that supports headless
    // has been published.
    // if (useChromeHeadless && headlessModeIsSupported) {
    //   args.add('--headless');
    // }
    final Process process =
        await Process.start(Platform.resolvedExecutable, args);

    return DevToolsServerDriver._(
        process,
        process.stdin,
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
        process.stderr.transform(utf8.decoder).transform(const LineSplitter()));
  }
}
