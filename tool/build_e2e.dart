// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

const argDevToolsBuild = 'devtools-build';

void main(List<String> args) async {
  final mainDevToolsDirectory = Directory.current;
  if (!mainDevToolsDirectory.path.endsWith('/devtools')) {
    throw Exception('Please execute this script from your top level '
        '\'devtools/\' directory.');
  }

  final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
  if (localDartSdkLocation == null) {
    throw Exception('LOCAL_DART_SDK environment variable not set. Please add '
        'the following to your \'.bash_profile\' or \'.bash_rc\' file:\n'
        'export LOCAL_DART_SDK=<absolute/path/to/my/dart/sdk>');
  }

  print('Running the build_release.sh script...');
  final buildProcess = await Process.start(
    './tool/build_release.sh',
    [],
    workingDirectory: mainDevToolsDirectory.path,
  );
  _printToConsole(buildProcess);
  await buildProcess.exitCode;

  final devToolsBuildLocation =
      '${mainDevToolsDirectory.path}/packages/devtools_app/build/web';

  print('Completed building DevTools: $devToolsBuildLocation');

  print('Serving DevTools with a local devtools server...');
  final serveProcess = await Process.start(
    'dart',
    [
      'pkg/dds/tool/devtools_server/serve_local.dart',
      '--devtools-build=$devToolsBuildLocation',
    ],
    workingDirectory: localDartSdkLocation,
  );
  _printToConsole(serveProcess);
  await serveProcess.exitCode;
}

void _printToConsole(Process process) {
  _transformToLines(process.stdout).listen(print);
  _transformToLines(process.stderr).listen(print);
}

Stream<String> _transformToLines(Stream<List<int>> byteStream) {
  return byteStream
      .transform<String>(utf8.decoder)
      .transform<String>(const LineSplitter());
}
