// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

abstract class DartSdkHelper {
  static const commandDebugMessage = 'Consider running this command from your'
      'Dart SDK directory locally to debug.';

  static Future<void> fetchAndCheckoutMaster(
    ProcessManager processManager,
  ) async {
    final dartSdkLocation = localDartSdkLocation();
    await processManager.runAll(
      workingDirectory: dartSdkLocation,
      additionalErrorMessage: commandDebugMessage,
      commands: [
        CliCommand.git(['fetch origin']),
        CliCommand.git(['rebase-update']),
        CliCommand.git(['checkout origin/main']),
      ],
    );
  }
}

String localDartSdkLocation() {
  final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
  if (localDartSdkLocation == null) {
    throw Exception('LOCAL_DART_SDK environment variable not set. Please add '
        'the following to your \'.bash_profile\' or \'.bash_rc\' file:\n'
        'export LOCAL_DART_SDK=<absolute/path/to/my/dart/sdk>');
  }
  return localDartSdkLocation;
}

class CliCommand {
  CliCommand._({
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

  CliCommand(
    String command, {
    this.throwOnException = true,
  })  : exe = command.split(' ').first,
        args = command.split(' ').sublist(1);

  factory CliCommand.from(
    String exe,
    List<String> args, {
    bool throwOnException = true,
  }) {
    return CliCommand._(
      exe: exe,
      args: args,
      throwOnException: throwOnException,
    );
  }

  factory CliCommand.flutter(
    String args, {
    bool throwOnException = true,
  }) {
    final sdk = FlutterSdk.current;
    if (sdk == null) {
      throw Exception('Unable to locate a Flutter sdk.');
    }

    return CliCommand._(
      exe: sdk.flutterToolPath,
      args: args.split(' '),
      throwOnException: throwOnException,
    );
  }

  /// CliCommand helper for running git commands.
  ///
  /// Arguments can be passed in as a single string, this helper will split them
  /// up using their spaces. e.g. CliCommand.git(['checkout test-branch'])
  ///
  /// If you don't want the args to be split by their spaces then you can set
  /// [split] to false.
  factory CliCommand.git(
    List<String> args, {
    bool throwOnException = true,
    bool split = true,
  }) {
    if (split) {
      args = args.map((e) => e.split(' ')).reduce((value, element) {
        value.addAll(element);
        return value;
      });
    }
    return CliCommand._(
      exe: 'git',
      args: args,
      throwOnException: throwOnException,
    );
  }

  factory CliCommand.tool(
    String args, {
    bool throwOnException = true,
  }) {
    return CliCommand._(
      exe: Platform.isWindows ? 'devtools_tool.bat' : 'devtools_tool',
      args: args.split(' '),
      throwOnException: throwOnException,
    );
  }

  late final String exe;
  late final List<String> args;
  final bool throwOnException;

  @override
  String toString() {
    return [exe, ...args].join(' ');
  }
}

typedef DevToolsProcessResult = ({int exitCode, String stdout, String stderr});

extension DevToolsProcessManagerExtension on ProcessManager {
  Future<DevToolsProcessResult> runProcess(
    CliCommand command, {
    String? workingDirectory,
    String? additionalErrorMessage = '',
  }) async {
    print('${workingDirectory ?? ''} > $command');
    final processStdout = StringBuffer();
    final processStderr = StringBuffer();

    final process = await spawn(
      command.exe,
      command.args,
      workingDirectory: workingDirectory,
    );
    process.stdout.transform(utf8.decoder).listen(processStdout.write);
    process.stderr.transform(utf8.decoder).listen(processStderr.write);
    final code = await process.exitCode;
    if (command.throwOnException && code != 0) {
      throw ProcessException(
        command.exe,
        command.args,
        'Failed with exit code: $code. $additionalErrorMessage',
        code,
      );
    }
    return (
      exitCode: code,
      stdout: processStdout.toString(),
      stderr: processStderr.toString()
    );
  }

  Future<void> runAll({
    required List<CliCommand> commands,
    String? workingDirectory,
    String? additionalErrorMessage = '',
  }) async {
    for (final command in commands) {
      await runProcess(
        command,
        workingDirectory: workingDirectory,
        additionalErrorMessage: additionalErrorMessage,
      );
    }
  }
}

String pathFromRepoRoot(String pathFromRoot) {
  return path.join(DevToolsRepo.getInstance().repoPath, pathFromRoot);
}

/// Returns the name of the git remote with id [remoteId] in
/// [workingDirectory].
///
/// When [workingDirectory] is null, this method will look for the remote in
/// the current directory.
///
/// [remoteId] should have the form <organization>/<repository>.git. For
/// example: 'flutter/flutter.git' or 'flutter/devtools.git'.
Future<String> findRemote(
  ProcessManager processManager, {
  required String remoteId,
  String? workingDirectory,
}) async {
  print('Searching for a remote that points to $remoteId.');
  final remotesResult = await processManager.runProcess(
    CliCommand.git(['remote -v']),
    workingDirectory: workingDirectory,
  );
  final String remotes = remotesResult.stdout;
  final remoteRegexp = RegExp(
    r'^(?<remote>\S+)\s+(?<path>\S+)\s+\((?<action>\S+)\)',
    multiLine: true,
  );
  final remoteRegexpResults = remoteRegexp.allMatches(remotes);
  final RegExpMatch upstreamRemoteResult;

  try {
    upstreamRemoteResult = remoteRegexpResults.firstWhere(
      (element) =>
          // ignore: prefer_interpolation_to_compose_strings
          RegExp(r'' + remoteId + '\$').hasMatch(element.namedGroup('path')!),
    );
  } on StateError {
    throw StateError(
      "Couldn't find a remote that points to flutter/devtools.git. "
      "Instead got: \n$remotes",
    );
  }
  final remoteUpstream = upstreamRemoteResult.namedGroup('remote')!;
  print('Found upstream remote.');
  return remoteUpstream;
}

extension CommandExtension on Command {
  void logStatus(String log) {
    print('[$name] $log');
  }
}

extension JoinExtension on List<String> {
  String joinWithNewLine() {
    return '${join('\n')}\n';
  }
}
