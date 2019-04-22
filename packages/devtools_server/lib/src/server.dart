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

  final devToolsUrl = 'http://${server.address.host}:${server.port}';

  printOutput(
    'Serving DevTools at $devToolsUrl',
    {
      'method': 'server.started',
      'params': {'host': server.address.host, 'port': server.port, 'pid': pid}
    },
    machineMode: machineMode,
  );

  final Stream<Map<String, dynamic>> _stdinCommandStream = stdin
      .transform<String>(utf8.decoder)
      .transform<String>(const LineSplitter())
      .where((String line) => line.startsWith('{') && line.endsWith('}'))
      .map<Map<String, dynamic>>((String line) {
    return json.decode(line) as Map<String, dynamic>;
  });

  // Example input:
  // {
  //   "id":0,
  //   "method":"vm.register",
  //   "params":{
  //     "uri":"<vm-service-uri-here>",
  //   }
  // }
  _stdinCommandStream.listen((Map<String, dynamic> json) async {
    final dynamic id = json['id'];
    final Map<String, dynamic> params = json['params'];

    switch (json['method']) {
      case 'vm.register':
        await _handleVmRegister(id, params, machineMode, devToolsUrl);
        break;
      default:
        printOutput(
          'Unknown command ${json['method']}',
          {
            'id': id,
            'error': 'Unknown method ${json['method']}',
          },
          machineMode: machineMode,
        );
    }
  });
}

Future _handleVmRegister(dynamic id, Map<String, dynamic> params,
    bool machineMode, String devToolsUrl) async {
  if (!params.containsKey('uri')) {
    printOutput(
      'Invalid input: $params does not contain the key \'uri\'',
      {
        'id': id,
        'error': 'Invalid input: $params does not contain the key \'uri\'',
      },
      machineMode: machineMode,
    );
  }

  // json['uri'] should contain a vm service uri.
  final uri = Uri.parse(params['uri']);

  // Lots of things are considered valid URIs (including empty strings
  // and single letters) since they can be relative, so we need to do some
  // extra checks.
  if (uri != null &&
      uri.isAbsolute &&
      (uri.isScheme('ws') ||
          uri.isScheme('wss') ||
          uri.isScheme('http') ||
          uri.isScheme('https')))
    await registerLaunchDevToolsService(uri, id, devToolsUrl, machineMode);
}

Future<void> registerLaunchDevToolsService(
  Uri uri,
  dynamic id,
  String devToolsUrl,
  bool machineMode,
) async {
  try {
    // Connect to the vm service and register a method to launch DevTools in
    // chrome.
    final VmService service = await _connectToVmService(uri);

    service.registerServiceCallback(launchDevToolsService, (request) async {
      // TODO(kenzie): modify this to append arguments (i.e. theme=dark). This
      // likely will require passing in args.
      final url = '$devToolsUrl/?uri=${Uri.encodeComponent(uri.toString())}';

      // TODO(kenzie): depend on the browser_launcher package for this once it
      // is complete.
      await Chrome.start([url]);

      return {'result': Success().toJson()};
    });

    await service.registerService(launchDevToolsService, 'DevTools Server');

    printOutput(
      'Successfully registered launchDevTools service',
      {
        'id': id,
        'result': {'success': true},
      },
      machineMode: machineMode,
    );
  } catch (e) {
    printOutput(
      'Unable to connect to VM service at $uri: $e',
      {
        'id': id,
        'error': 'Unable to connect to VM service at $uri: $e',
      },
      machineMode: machineMode,
    );
  }
}

Future<VmService> _connectToVmService(Uri uri) async {
  // Fix up the various acceptable URI formats into a WebSocket URI to connect.
  uri = getVmServiceUriFromObservatoryUri(uri);

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

/// Map the URI (which may already be Observatory web app) to a WebSocket URI
/// for the VM service. If the URI is already a VM Service WebSocket URI it
/// will not be modified.
Uri getVmServiceUriFromObservatoryUri(Uri uri) {
  final isSecure = uri.isScheme('wss') || uri.isScheme('https');
  final scheme = isSecure ? 'wss' : 'ws';

  final path = uri.path.endsWith('/ws')
      ? uri.path
      : (uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws');

  return uri.replace(scheme: scheme, path: path);
}
