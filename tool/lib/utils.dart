// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
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
        CliCommand.git(['fetch', 'origin']),
        CliCommand.git(['rebase-update']),
        CliCommand.git(['checkout', 'origin/main']),
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
  CliCommand(
    this.exe,
    // Args is mandatory to make it clearer to the caller that they should
    // not be passing a full exe+args into the first string argument, because
    // this can lead to bugs if paths have spaces and everything is not escaped.
    this.args, {
    this.throwOnException = true,
  });

  factory CliCommand.flutter(
    List<String> args, {
    bool throwOnException = true,
  }) {
    return CliCommand(
      FlutterSdk.current.flutterExePath,
      args,
      throwOnException: throwOnException,
    );
  }

  factory CliCommand.dart(
    List<String> args, {
    bool throwOnException = true,
  }) {
    return CliCommand(
      FlutterSdk.current.dartExePath,
      args,
      throwOnException: throwOnException,
    );
  }

  /// CliCommand helper for running git commands.
  factory CliCommand.git(
    List<String> args, {
    bool throwOnException = true,
  }) {
    return CliCommand(
      'git',
      args,
      throwOnException: throwOnException,
    );
  }

  factory CliCommand.tool(
    List<String> args, {
    bool throwOnException = true,
  }) {
    // We do not use `Platform.script.toFilePath()`
    // assuming path to the tool is in the PATH
    // because of bug https://github.com/dart-lang/sdk/issues/54493

    var toolPath = Platform.script.toFilePath();
    if (!File(toolPath).existsSync()) {
      // Handling https://github.com/dart-lang/sdk/issues/54493
      toolPath = toolPath.replaceAll(
        'devtools/tool/tool/bin/devtools_tool.dart',
        'devtools/tool/bin/devtools_tool.dart',
      );
    }

    assert(
      File(toolPath).existsSync(),
      'Tool path is detected wrongly: $toolPath.'
      'It can be result of https://github.com/dart-lang/sdk/issues/54493',
    );

    return CliCommand(
      // We must use the Dart VM from FlutterSdk.current here to ensure we
      // consistently use the selected version for child invocations. We do
      // not need to pass the --flutter-from-path flag down because using the
      // tool will automatically select the one that's running the VM and we'll
      // have selected that here.
      FlutterSdk.current.dartExePath,
      [
        toolPath,
        ...args,
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
    CliCommand.git(['remote', '-v']),
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
