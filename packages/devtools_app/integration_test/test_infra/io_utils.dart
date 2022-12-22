// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
    void Function(String)? onError,
  }) {
    streamSubscriptions.addAll([
      transformToLines(process.stdout)
          .listen((String line) => stdoutController.add(line)),
      transformToLines(process.stderr).listen((String line) {
        if (onError != null) {
          onError(line);
        }
        stderrController.add(line);
      }),

      // This is just debug printing to aid running/debugging tests locally.
      stdoutController.stream.listen(printCallback),
      stderrController.stream.listen(printCallback),
    ]);
  }

  Future<void> cancelAllStreamSubscriptions() async {
    await Future.wait(streamSubscriptions.map((s) => s.cancel()));
    streamSubscriptions.clear();
  }

  static void _defaultPrintCallback(String line) {
    print(line);
  }
}
