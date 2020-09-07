// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chrome.dart';

const verbose = true;

class DevToolsServerDriver {
  DevToolsServerDriver._(
    this._process,
    this._stdin,
    Stream<String> _stdout,
    Stream<String> _stderr,
  )   : stdout = _convertToMapStream(_stdout),
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

  static Stream<Map<String, dynamic>> _convertToMapStream(
    Stream<String> stream,
  ) {
    return stream.map((line) {
      _trace('<== $line');
      return line;
    }).map((line) {
      try {
        return jsonDecode(line) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }).where((item) => item != null);
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
    List<String> additionalArgs = const [],
  }) async {
    // Here, we call the 'dart' command once, in order to ensure that it's not
    // in use from elsewhere.
    // TODO: file a bug about this - the 'flutter/bin/dart' script should not
    // generally print "Waiting for another flutter command to release the
    // startup lock..."
    final Stopwatch timer = Stopwatch()..start();
    final ProcessResult result = await Process.run('dart', ['--version']);
    print('dart --version ran in ${timer.elapsed}.');
    print(result.stdout);

    // These tests assume that the devtools package is present in a sibling
    // directory of the devtools_app package.
    final args = [
      '../devtools/bin/devtools.dart',
      '--machine',
      '--port',
      '$port',
      ...additionalArgs
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
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()),
    );
  }
}
