// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
        CliCommand.git(cmd: 'fetch origin'),
        CliCommand.git(cmd: 'rebase-update'),
        CliCommand.git(cmd: 'checkout origin/main'),
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
    return CliCommand._(
      exe: sdk.flutterToolPath,
      args: args.split(' '),
      throwOnException: throwOnException,
    );
  }

  /// CliCommand helper for running git commands.
  ///
  /// Arguments can be passed in as a single string using [cmd], this will split
  /// the string into args using spaces. e.g. CliCommand.git(cmd: 'checkout test-branch')
  ///
  /// If you instead want to specify args explicitly, you can use the
  /// [args] param. e.g. CliCommand.git(args: ['checkout', 'test-branch'])
  factory CliCommand.git({
    String? cmd,
    List<String>? args,
    bool throwOnException = true,
    bool split = true,
  }) {
    if ((cmd == null) == (args == null)) {
      throw ('Only one of `cmd` and `args` must be specified.');
    }

    if (cmd != null) {
      args = cmd.split(' ');
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
      // We must use the Dart VM from FlutterSdk.current here to ensure we
      // consistently use the selected version for child invocations. We do
      // not need to pass the --flutter-from-path flag down because using the
      // tool will automatically select the one that's running the VM and we'll
      // have selected that here.
      exe: FlutterSdk.current.dartToolPath,
      args: [
        Platform.script.toFilePath(),
        ...args.split(' '),
      ],
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
    CliCommand.git(cmd: 'remote -v'),
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

extension JoinExtension on List<String> {
  String joinWithNewLine() {
    return '${join('\n')}\n';
  }
}
