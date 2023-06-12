// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Stream<String> transformToLines(Stream<List<int>> byteStream) {
  return byteStream
      .transform<String>(utf8.decoder)
      .transform<String>(const LineSplitter());
}

mixin IOMixin {
  final stdoutController = StreamController<String>.broadcast();

  final stderrController = StreamController<String>.broadcast();

  final streamSubscriptions = <StreamSubscription<String>>[];

  void listenToProcessOutput(
    Process process, {
    void Function(String) printCallback = _defaultPrintCallback,
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) {
    streamSubscriptions.addAll([
      transformToLines(process.stdout).listen((String line) {
        onStdout?.call(line);
        stdoutController.add(line);
      }),
      transformToLines(process.stderr).listen((String line) {
        onStderr?.call(line);
        stderrController.add(line);
      }),

      // This is just debug printing to aid running/debugging tests locally.
      stdoutController.stream.listen(printCallback),
      stderrController.stream.listen(printCallback),
    ]);
  }

  Future<void> cancelAllStreamSubscriptions() async {
    await Future.wait(streamSubscriptions.map((s) => s.cancel()));
    await Future.wait([
      stdoutController.close(),
      stderrController.close(),
    ]);
    streamSubscriptions.clear();
  }

  static void _defaultPrintCallback(String line) {
    print(line);
  }
}
