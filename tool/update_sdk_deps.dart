// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

const _argCommit = 'commit';

/// This script updates the "devtools_rev" hash in the Dart SDK DEPS file with
/// the provided commit hash, and creates a Gerrit CL for review.
///
/// This hash is the ID for a DevTools build stored in CIPD, which is
/// automatically built and uploaded to CIPD on each DevTools commit.
///
/// To run this script: `dart update_sdk_deps.dart -c <commit-hash>`
void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      _argCommit,
      abbr: 'c',
      help: 'The DevTools commit hash to release into the Dart SDK.',
      mandatory: true,
    );
  final argResults = parser.parse(args);
  final commit = argResults[_argCommit];

  final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
  if (localDartSdkLocation == null) {
    throw Exception('LOCAL_DART_SDK environment variable not set. Please add '
        'the following to your \'.bash_profile\' or \'.bash_rc\' file:\n'
        'export LOCAL_DART_SDK=<absolute/path/to/my/dart/sdk>');
  }

  final processManager = ProcessManager();

  print('Preparing a local Dart SDK branch...');
  await _runAll(
    processManager,
    workingDirectory: localDartSdkLocation,
    commands: [
      _Command('git fetch origin'),
      _Command('git rebase-update'),
      _Command('git checkout origin/main'),
      _Command(
        'git branch -D devtools-$commit',
        throwOnException: false,
      ),
      _Command('git new-branch devtools-$commit'),
    ],
  );

  print('Updating the DEPS file with the new DevTools hash...');
  _writeToDepsFile(commit, localDartSdkLocation);

  print('Committing the changes and creating a Gerrit CL...');
  await _runAll(
    processManager,
    workingDirectory: localDartSdkLocation,
    commands: [
      _Command('git add .'),
      _Command.from(
        'git',
        [
          'commit',
          '-m',
          'Update DevTools rev to $commit',
        ],
      ),
      // TODO(kenz): is there a way to automatically close the file that pops up
      // with the commit description?
      _Command('git cl upload -s'),
    ],
  );

  // Closes stdin for the entire program.
  await sharedStdIn.terminate();
}

void _writeToDepsFile(String commit, String localDartSdkLocation) {
  final depsFilePath = path.join(localDartSdkLocation, 'DEPS');
  final depsFile = File(depsFilePath);
  if (!depsFile.existsSync()) {
    throw Exception('Count not find SDK DEPS file at: $depsFilePath');
  }

  final devToolsRevMarker = '  "devtools_rev":';
  final newFileContent = StringBuffer();
  final lines = depsFile.readAsLinesSync();
  for (final line in lines) {
    if (line.startsWith(devToolsRevMarker)) {
      newFileContent.writeln('$devToolsRevMarker "$commit",');
    } else {
      newFileContent.writeln(line);
    }
  }
  depsFile.writeAsStringSync(newFileContent.toString());
}

Future<void> _runAll(
  ProcessManager processManager, {
  required List<_Command> commands,
  String? workingDirectory,
}) async {
  for (final command in commands) {
    await _runProcess(
      processManager,
      command,
      workingDirectory: workingDirectory,
    );
  }
}

Future<void> _runProcess(
  ProcessManager processManager,
  _Command command, {
  String? workingDirectory,
}) async {
  final process = await processManager.spawn(
    command.exe,
    command.args,
    workingDirectory: workingDirectory,
  );
  final code = await process.exitCode;
  if (command.throwOnException && code != 0) {
    throw ProcessException(
      command.exe,
      command.args,
      'Failed with exit code: $code. Consider running this command from your'
      'Dart SDK directory locally to debug.',
      code,
    );
  }
}

class _Command {
  _Command._({
    String? command,
    String? exe,
    List<String>? args,
    this.throwOnException = true,
  }) {
    assert((command == null) != ((exe == null) && (args == null)));
    final commandElements = command?.split(' ');
    this.exe = exe ?? commandElements!.first;
    this.args = args ?? commandElements!.sublist(1);
  }

  _Command(
    String command, {
    this.throwOnException = true,
  })  : exe = command.split(' ').first,
        args = command.split(' ').sublist(1);

  factory _Command.from(
    String exe,
    List<String> args, {
    bool throwOnException = true,
  }) {
    return _Command._(
      exe: exe,
      args: args,
      throwOnException: throwOnException,
    );
  }

  late final String exe;
  late final List<String> args;
  final bool throwOnException;
}
