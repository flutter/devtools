// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools/src/vm_service_wrapper.dart';
import 'package:vm_service_lib/vm_service_lib.dart';
import 'package:vm_service_lib/vm_service_lib_io.dart';

class AppFixture {
  AppFixture._(
    this.process,
    this.lines,
    this.servicePort,
    this.serviceConnection,
    this.isolates,
  ) {
    // "starting app"
    _onAppStarted = lines.first;

    serviceConnection.streamListen('Isolate');
    serviceConnection.onIsolateEvent.listen((Event event) {
      if (event.kind == EventKind.kIsolateExit) {
        isolates.remove(event.isolate);
      } else {
        if (!isolates.contains(event.isolate)) {
          isolates.add(event.isolate);
        }
      }
    });
  }

  final Process process;
  final Stream<String> lines;
  final int servicePort;
  final VmServiceWrapper serviceConnection;
  final List<IsolateRef> isolates;
  Future<void> _onAppStarted;

  Future<void> get onAppStarted => _onAppStarted;

  IsolateRef get mainIsolate => isolates.isEmpty ? null : isolates.first;

  Future<dynamic> invoke(String expression) async {
    final IsolateRef isolateRef = mainIsolate;
    final Isolate isolate = await serviceConnection.getIsolate(isolateRef.id);

    return await serviceConnection.evaluate(
        isolateRef.id, isolate.rootLib.id, expression);
  }

  Future<void> teardown() async {
    serviceConnection.dispose();
    process.kill();
  }
}

// This is the fixture for Dart CLI applications.
class CliAppFixture extends AppFixture {
  CliAppFixture._(
    this.appScriptPath,
    Process process,
    Stream<String> lines,
    int servicePort,
    VmServiceWrapper serviceConnection,
    List<IsolateRef> isolates,
  ) : super._(process, lines, servicePort, serviceConnection, isolates);

  final String appScriptPath;

  static Future<CliAppFixture> create(String appScriptPath) async {
    final Process process = await Process.start(
      Platform.resolvedExecutable,
      <String>['--observe=0', appScriptPath],
    );

    final Stream<String> lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final StreamController<String> lineController =
        StreamController<String>.broadcast();
    final Completer<String> completer = Completer<String>();

    lines.listen((String line) {
      if (completer.isCompleted) {
        lineController.add(line);
      } else {
        completer.complete(line);
      }
    });

    // Observatory listening on http://127.0.0.1:9595/
    String observatoryText = await completer.future;
    observatoryText =
        observatoryText.substring(observatoryText.lastIndexOf(':') + 1);
    observatoryText = observatoryText.substring(0, observatoryText.length - 1);
    final int port = int.parse(observatoryText);

    final VmServiceWrapper serviceConnection =
        VmServiceWrapper(await vmServiceConnect('localhost', port));

    final VM vm = await serviceConnection.getVM();

    return CliAppFixture._(
      appScriptPath,
      process,
      lineController.stream,
      port,
      serviceConnection,
      vm.isolates,
    );
  }

  String get scriptSource {
    return File(appScriptPath).readAsStringSync();
  }

  static List<int> parseBreakpointLines(String source) {
    return _parseLines(source, 'breakpoint');
  }

  static List<int> parseSteppingLines(String source) {
    return _parseLines(source, 'step');
  }

  static List<int> parseExceptionLines(String source) {
    return _parseLines(source, 'exception');
  }

  static List<int> _parseLines(String source, String keyword) {
    final List<String> lines = source.replaceAll('\r', '').split('\n');
    final List<int> matches = [];

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].endsWith('// $keyword')) {
        matches.add(i);
      }
    }

    return matches;
  }
}
