import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final VmService serviceConnection;
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
    Process process,
    Stream<String> lines,
    int servicePort,
    VmService serviceConnection,
    List<IsolateRef> isolates,
  ) : super._(process, lines, servicePort, serviceConnection, isolates);

  static Future<CliAppFixture> create(String appScriptPath) async {
    final Process process = await Process.start(
      Platform.resolvedExecutable,
      <String>['--observe=0', appScriptPath],
    );

    final Stream<String> lines =
        process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final StreamController<String> lineController =
        new StreamController<String>.broadcast();
    final Completer<String> completer = new Completer<String>();

    lines.listen((String line) {
      print('in CliAppFixture line listen - line: $line');
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

    final VmService serviceConnection =
        await vmServiceConnect('localhost', port);

    final VM vm = await serviceConnection.getVM();
    return new CliAppFixture._(
        process, lineController.stream, port, serviceConnection, vm.isolates);
  }
}

// This is the fixture for Flutter applications.
class FlutterAppFixture extends AppFixture {
  FlutterAppFixture._(
      Process process,
      Stream<String> lines,
      int servicePort,
      VmService serviceConnection,
      List<IsolateRef> isolates,
      ) : super._(process, lines, servicePort, serviceConnection, isolates);

  static Future<FlutterAppFixture> create() async {
    final Process process = await Process.start(
        'flutter', <String>['run', '-d', 'flutter-tester', '--machine'],
        workingDirectory: 'test/fixtures/flutter_app');

    final Stream<String> lines =
    process.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final StreamController<String> lineController =
    new StreamController<String>.broadcast();
    final Completer<String> completer = new Completer<String>();

    lines.listen((String line) {
      if (line.contains('"port":')) {
        if (completer.isCompleted) {
          lineController.add(line);
        } else {
          completer.complete(line);
        }
      }
    });

    final String line = await completer.future;
    final List<dynamic> decodedJson = json.decode(line);
    final Map<String, Object> jsonMap = decodedJson[0];
    final Map<String, Object> params = jsonMap['params'];
    final int port = params['port'];

    final VmService serviceConnection =
    await vmServiceConnect('localhost', port);

    final VM vm = await serviceConnection.getVM();

    return new FlutterAppFixture._(
        process, lineController.stream, port, serviceConnection, vm.isolates);
  }
}
