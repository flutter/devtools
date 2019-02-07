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
    help: 'Port to serve DevTools on. '
        'Pass 0 to automatically assign an available port.',
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
  final port = args[argPort] != null ? int.tryParse(args[argPort]) ?? 0 : 0;

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

  final server = await shelf.serve(handler, '127.0.0.1', port);

  printOutput(
    'Serving DevTools at http://${server.address.host}:${server.port}',
    {
      'method': 'server.started',
      'params': {'host': server.address.host, 'port': server.port}
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
