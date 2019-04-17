// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_static/shelf_static.dart';
import 'package:vm_service_lib/vm_service_lib.dart' hide Isolate;

import 'chrome.dart';

const argHelp = 'help';
const argMachine = 'machine';
const argPort = 'port';
const launchDevToolsService = 'launchDevTools';

final argParser = new ArgParser()
  ..addFlag(
    argHelp,
    negatable: false,
    abbr: 'h',
    help: 'Prints help output.',
  )
  ..addOption(
    argPort,
    defaultsTo: '9100',
    abbr: 'p',
    help: 'Port to serve DevTools on. '
        'Pass 0 to automatically assign an available port.',
  )
  ..addFlag(
    argMachine,
    negatable: false,
    abbr: 'm',
    help: 'Sets output format to JSON for consumption in tools.',
  );

void serveDevToolsWithArgs(List<String> arguments) async {
  final args = argParser.parse(arguments);

  final help = args[argHelp];
  final bool machineMode = args[argMachine];
  final port = args[argPort] != null ? int.tryParse(args[argPort]) ?? 0 : 0;

  serveDevTools(help: help, machineMode: machineMode, port: port);
}

void serveDevTools({
  bool help = false,
  bool machineMode = false,
  int port = 0,
}) async {
  if (help) {
    print('Dart DevTools version ${await _getVersion()}');
    print('');
    print('usage: devtools <options>');
    print('');
    print(argParser.usage);
    return;
  }

  final Uri resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));

  // Default static handler for all non-package requests.
  final String buildDir = path.join(packageDir, 'build');
  final buildHandler = createStaticHandler(
    buildDir,
    defaultDocument: 'index.html',
  );

  // The packages folder is renamed in the pub package so this handler serves
  // out of the `pack` folder.
  final String packagesDir = path.join(packageDir, 'build', 'pack');
  final packHandler = createStaticHandler(
    packagesDir,
    defaultDocument: 'index.html',
  );

  // Make a handler that delegates to the correct handler based on path.
  final handler = (shelf.Request request) {
    return request.url.path.startsWith('packages/')
        // request.change here will strip the `packages` prefix from the path
        // so it's relative to packHandler's root.
        ? packHandler(request.change(path: 'packages'))
        : buildHandler(request);
  };

  final server = await shelf.serve(handler, '127.0.0.1', port);

  final devtoolsUrl = 'http://${server.address.host}:${server.port}';

  printOutput(
    'Serving DevTools at $devtoolsUrl',
    {
      'method': 'server.started',
      'params': {'host': server.address.host, 'port': server.port, 'pid': pid}
    },
    machineMode: machineMode,
  );

  _listenForUris(devtoolsUrl);
}

void _listenForUris(String devtoolsUrl) {
  final Stream<Map<String, dynamic>> _stdinCommandStream = stdin
      .transform<String>(utf8.decoder)
      .transform<String>(const LineSplitter())
      .where((String line) => line.startsWith('[{') && line.endsWith('}]'))
      .map<Map<String, dynamic>>((String line) {
    line = line.substring(1, line.length - 1);
    return json.decode(line) as Map<String, dynamic>;
  });

  // Example json input: [{"url":"ws://localhost:8888/ws"}]
  _stdinCommandStream.listen((Map<String, dynamic> json) async {
    final line = json['url'];

    final uri = Uri.parse(line);

    // Lots of things are considered valid URIs (including empty strings
    // and single letters) since they can be relative, so we need to do some
    // extra checks.
    if (uri != null &&
        uri.isAbsolute &&
        (uri.isScheme('ws') ||
            uri.isScheme('wss') ||
            uri.isScheme('http') ||
            uri.isScheme('https')))
      try {
        // Connect to the vm service and register a method to launch DevTools in
        // chrome.
        final VmService service = await _connectToVmService(uri);

        service.registerServiceCallback(launchDevToolsService, (request) async {
          String vmServicePort =
              uri.toString().substring(uri.toString().lastIndexOf(':') + 1);
          vmServicePort =
              vmServicePort.substring(0, vmServicePort.indexOf('/'));

          final url = '$devtoolsUrl/?port=$vmServicePort#';

          // TODO(kenzie): depend on the browser_launcher package for this once
          // it is complete.
          await Chrome.start([url]);

          return {'result': Success().toJson()};
        });

        await service.registerService(launchDevToolsService, 'DevTools Server');
      } catch (e) {
        print('Unable to connect to VM service at $uri: $e');
        return;
      }
  });
}

Future<VmService> _connectToVmService(Uri uri) async {
  final WebSocket ws = await WebSocket.connect(uri.toString());

  final VmService service = VmService(
    ws.asBroadcastStream(),
    (String message) => ws.add(message),
  );

  return service;
}

Future<String> _getVersion() async {
  final Uri resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final String packageDir =
      path.dirname(path.dirname(resourceUri.toFilePath()));
  final File pubspecFile = File(path.join(packageDir, 'pubspec.yaml'));
  final String versionLine =
      pubspecFile.readAsLinesSync().firstWhere((String line) {
    return line.startsWith('version: ');
  }, orElse: () => null);
  return versionLine == null
      ? 'unknown'
      : versionLine.substring('version: '.length).trim();
}

void printOutput(
  String message,
  Object json, {
  @required bool machineMode,
}) {
  print(machineMode ? jsonEncode(json) : message);
}
