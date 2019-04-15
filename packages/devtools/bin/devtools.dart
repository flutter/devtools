// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf;
import 'package:shelf_static/shelf_static.dart';

const argHelp = 'help';
const argMachine = 'machine';
const argPort = 'port';

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
    // ChromeOS exposed ports: 8000, 8008, 808, 8085, 8888, 9005, 3000, 4200, 5000
    help: 'Port to serve DevTools on. '
        'Pass 0 to automatically assign an available port. Pass a comma-'
        'separated list to try multiple ports in order before failing.',
  )
  ..addFlag(
    argMachine,
    negatable: false,
    abbr: 'm',
    help: 'Sets output format to JSON for consumption in tools.',
  );

void main(List<String> arguments) async {
  final args = argParser.parse(arguments);
  if (args[argHelp]) {
    print('Dart DevTools version ${await _getVersion()}');
    print('');
    print('usage: devtools <options>');
    print('');
    print(argParser.usage);
    return;
  }

  final bool machineMode = args[argMachine];

  final Uri resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));

  // Default static handler for all non-package requests.
  final String buildDir = path.join(packageDir, 'build');
  final buildHandler =
      createStaticHandler(buildDir, defaultDocument: 'index.html');

  // The packages folder is renamed in the pub package so this handler serves
  // out of the `pack` folder.
  final String packagesDir = path.join(packageDir, 'build', 'pack');
  final packHandler =
      createStaticHandler(packagesDir, defaultDocument: 'index.html');

  // Make a handler that delegates to the correct handler based on path.
  final handler = (shelf.Request request) {
    return request.url.path.startsWith('packages/')
        // request.change here will strip the `packages` prefix from the path
        // so it's relative to packHandler's root.
        ? packHandler(request.change(path: 'packages'))
        : buildHandler(request);
  };

  final ports = args[argPort] != null
      ? args[argPort].split(',').map((i) => int.tryParse(i) ?? 0)
      : 0;

  // Attempt to bind to each port in order.
  HttpServer server;
  for (final port in ports) {
    try {
      server = await shelf.serve(handler, '127.0.0.1', port);
      break; // Don't try any more if we bound one.
    } on SocketException catch (e) {
      printOutput(
        'Unable to bind to port $port: $e',
        {
          'method': 'server.log',
          'params': {
            'level': 'info',
            'message': 'Unable to bind to port $port: $e'
          },
        },
        machineMode: machineMode,
      );
    }
  }

  if (server == null) {
    printOutput(
      'Unable to bind to any of the supplied ports. Include 0 in the list of '
      'ports to accept a randomly assign available port.',
      {
        'method': 'server.error',
        'params': {
          'message': 'Unable to bind to any of the supplied ports.',
          'fatal': true,
        }
      },
      machineMode: machineMode,
    );
    return;
  }

  printOutput(
    'Serving DevTools at http://${server.address.host}:${server.port}',
    {
      'method': 'server.started',
      'params': {'host': server.address.host, 'port': server.port, 'pid': pid}
    },
    machineMode: machineMode,
  );
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
