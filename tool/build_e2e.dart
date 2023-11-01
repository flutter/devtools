// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

const argNoBuildApp = '--no-build-app';
const argUseLocalFlutter = '--use-local-flutter';
const argUpdatePerfetto = '--update-perfetto';

/// This script builds DevTools in release mode by running the
/// `devtools_tool build-release` command and then serves DevTools with a
/// locally running DevTools server.
///
/// If [argNoBuildApp] is present, the DevTools web app will not be rebuilt.
///
/// If [argNoUpdateFlutter] is present, the Flutter SDK will not be updated to
/// the latest Flutter candidate. Use this flag to save the cost of updating the
/// Flutter SDK when you already have the proper SDK checked out.
///
/// If [argUpdatePerfetto] is present, the precompiled bits for Perfetto will
/// be updated from the [update_perfetto.sh] script as part of the DevTools
/// build process (e.g. [devtools_tool build-release]).
void main(List<String> args) async {
  final shouldUpdatePerfetto = args.contains(argUpdatePerfetto);
  final noUpdateFlutter = args.contains(argUseLocalFlutter);
  final noBuildApp = args.contains(argNoBuildApp);

  final argsCopy = List.of(args)
    ..remove(argUpdatePerfetto)
    ..remove(argUseLocalFlutter)
    ..remove(argNoBuildApp);

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

  final devToolsBuildLocation =
      '${mainDevToolsDirectory.path}/packages/devtools_app/build/web';

  if (!noBuildApp) {
    print('Building DevTools in release mode...');
    final buildProcess = await Process.start(
      'devtools_tool',
      [
        'build-release',
        if (shouldUpdatePerfetto) argUpdatePerfetto,
        if (noUpdateFlutter) argUseLocalFlutter,
      ],
      workingDirectory: mainDevToolsDirectory.path,
    );
    _forwardOutputStreams(buildProcess);
    final buildProcessExitCode = await buildProcess.exitCode;
    if (buildProcessExitCode == 1) {
      throw Exception(
        'Something went wrong while running `devtools_tool build-release',
      );
    }
    print('Completed building DevTools: $devToolsBuildLocation');
  }

  print('Run pub get for DDS in local dart sdk');
  await Process.start(
    'dart',
    ['pub', 'get'],
    workingDirectory: '$localDartSdkLocation/pkg/dds',
  );

  print('Serving DevTools with a local devtools server...');
  final serveProcess = await Process.start(
    'dart',
    [
      'pkg/dds/tool/devtools_server/serve_local.dart',
      '--devtools-build=$devToolsBuildLocation',
      // Pass any args that were provided to our script along. This allows IDEs
      // to pass `--machine` (etc.) so that this script can behave the same as
      // the "dart devtools" command for testing local DevTools/server changes.
      ...argsCopy,
    ],
    workingDirectory: localDartSdkLocation,
  );
  _forwardOutputStreams(serveProcess);
  _forwardInputStream(serveProcess);
  await serveProcess.exitCode;
}

void _forwardOutputStreams(Process process) {
  process.stdout.listen(stdout.add);
  process.stderr.listen(stdout.add);
}

void _forwardInputStream(Process process) {
  stdin.listen(process.stdin.add);
}
