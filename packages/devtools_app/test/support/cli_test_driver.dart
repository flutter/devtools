// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/vm_service_wrapper.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import '../integration_tests/integration.dart';

class AppFixture {
  AppFixture._(
    this.process,
    this.lines,
    this.serviceUri,
    this.serviceConnection,
    this.isolates,
  ) {
    // "starting app"
    _onAppStarted = lines.first;

    serviceConnection.streamListen(EventStreams.kIsolate);
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
  final Uri serviceUri;
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
    // Dispose is synchronous, so wait for it to finish closing before
    // terminating the process.
    await serviceConnection.onDone;
    process.kill();
  }
}

// This is the fixture for Dart CLI applications.
class CliAppFixture extends AppFixture {
  CliAppFixture._(
    this.appScriptPath,
    Process process,
    Stream<String> lines,
    Uri serviceUri,
    VmServiceWrapper serviceConnection,
    List<IsolateRef> isolates,
  ) : super._(process, lines, serviceUri, serviceConnection, isolates);

  final String appScriptPath;

  static Future<CliAppFixture> create(String appScriptPath) async {
    const String observatoryMarker = 'Observatory listening on ';

    final Process process = await Process.start(
      'dart',
      <String>['--observe=0', '--pause-isolates-on-start', appScriptPath],
    );

    final Stream<String> lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final StreamController<String> lineController =
        StreamController<String>.broadcast();
    final Completer<String> completer = Completer<String>();

    lines.listen((String line) {
      if (completer.isCompleted) {
        lineController.add(line);
      } else if (line.contains(observatoryMarker)) {
        completer.complete(line);
      } else {
        // Often something like:
        // "Waiting for another flutter command to release the startup lock...".
        print(line);
      }
    });

    // Observatory listening on http://127.0.0.1:9595/(token)
    final String observatoryText = await completer.future;
    final String observatoryUri =
        observatoryText.replaceAll(observatoryMarker, '');
    var uri = Uri.parse(observatoryUri);

    if (uri == null || !uri.isAbsolute) {
      throw 'Could not parse VM Service URI: "$observatoryText"';
    }

    // Map to WS URI.
    uri = convertToWebSocketUrl(serviceProtocolUrl: uri);

    final VmServiceWrapper serviceConnection =
        VmServiceWrapper(await vmServiceConnectUri(uri.toString()), uri);

    final VM vm = await serviceConnection.getVM();

    final Isolate isolate =
        await _waitForIsolate(serviceConnection, 'PauseStart');
    await serviceConnection.resume(isolate.id);

    return CliAppFixture._(
      appScriptPath,
      process,
      lineController.stream,
      uri,
      serviceConnection,
      vm.isolates,
    );
  }

  static Future<Isolate> _waitForIsolate(
    VmServiceWrapper serviceConnection,
    String pauseEventKind,
  ) async {
    Isolate foundIsolate;
    await waitFor(() async {
      final vm = await serviceConnection.getVM();
      final isolates = await Future.wait(vm.isolates.map(
        (ref) => serviceConnection
            .getIsolate(ref.id)
            // Calling getIsolate() can sometimes return a collected sentinel
            // for an isolate that hasn't started yet. We can just ignore these
            // as on the next trip around the Isolate will be returned.
            // https://github.com/dart-lang/sdk/issues/33747
            .catchError((error) =>
                print('getIsolate(${ref.id}) failed, skipping\n$error')),
      ));
      foundIsolate = isolates.firstWhere(
        (isolate) =>
            isolate is Isolate && isolate.pauseEvent.kind == pauseEventKind,
        orElse: () => null,
      );
      return foundIsolate != null;
    });
    return foundIsolate;
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
