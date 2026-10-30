// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

abstract class DartSdkHelper {
  static const commandDebugMessage =
      'Consider running this command from your'
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

/// Returns the name of the shell script [name] for the current platform.
///
/// On Windows, shell scripts have `.bat` extensions and must be invoked
/// using them.
String shellScriptName(String name) {
  return Platform.isWindows ? '$name.bat' : name;
}

String localDartSdkLocation() {
  final localDartSdkLocation = Platform.environment['LOCAL_DART_SDK'];
  if (localDartSdkLocation == null) {
    throw Exception(
      'LOCAL_DART_SDK environment variable not set. Please add '
      'the following to your \'.bash_profile\' or \'.bash_rc\' file:\n'
      'export LOCAL_DART_SDK=<absolute/path/to/my/dart/sdk>',
    );
  }
  return localDartSdkLocation;
}

/// Whether `dt` should forward its own stdin to the child processes it spawns.
///
/// We only forward stdin when it is attached to a terminal, which is the case
/// where a user may actually type input for a child process (for example,
/// hot reload commands for `flutter run` launched by `dt run`).
///
/// When stdin is not a terminal (for example, `/dev/null` on the CI bots),
/// listening to it reads it to EOF, and dart:io then closes file descriptor 0.
/// On macOS, the `posix_spawn`-based dart:io process implementation
/// (introduced in Dart SDK commit 0171629a5478) mishandles spawning child
/// processes once fd 0 has been closed and reused, which causes nested `dt`
/// invocations to hang forever waiting for a child process that has already
/// exited. Never listening to a non-terminal stdin avoids this. See
/// https://github.com/dart-lang/sdk/issues/64744.
// TODO(https://github.com/dart-lang/sdk/issues/64744): forward stdin
// unconditionally again once this is fixed in the Dart SDK.
final shouldForwardStdin = stdin.hasTerminal;

/// Creates a [ProcessManager] for spawning child processes from `dt`.
///
/// Use this instead of the default [ProcessManager] constructor, which always
/// listens to (and forwards) stdin. See [shouldForwardStdin] for details.
ProcessManager createProcessManager() => ProcessManager(
  stdin: shouldForwardStdin ? sharedStdIn : const Stream<List<int>>.empty(),
);

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
    String? sdkOverride,
  }) {
    return CliCommand(
      sdkOverride ?? FlutterSdk.current.dartExePath,
      args,
      throwOnException: throwOnException,
    );
  }

  /// CliCommand helper for running git commands.
  factory CliCommand.git(List<String> args, {bool throwOnException = true}) {
    return CliCommand('git', args, throwOnException: throwOnException);
  }

  /// CliCommand helper for running gclient commands.
  factory CliCommand.gclient(
    List<String> args, {
    bool throwOnException = true,
  }) {
    return CliCommand(
      shellScriptName('gclient'),
      args,
      throwOnException: throwOnException,
    );
  }

  factory CliCommand.tool(List<String> args, {bool throwOnException = true}) {
    var toolPath = Platform.script.toFilePath();
    if (!File(toolPath).existsSync()) {
      // Handling https://github.com/dart-lang/sdk/issues/54493
      // Platform.script.toFilePath() duplicates next to current directory, when run recursively from itself.
      toolPath = toolPath.replaceAll(
        'devtools/tool/tool/bin/dt.dart',
        'devtools/tool/bin/dt.dart',
      );
    }

    assert(
      File(toolPath).existsSync(),
      'Tool path could not be determined, got: $toolPath.'
      'It may be result of https://github.com/dart-lang/sdk/issues/54493',
    );

    return CliCommand(
      // We must use the Dart VM from FlutterSdk.current here to ensure we
      // consistently use the selected version for child invocations. We do
      // not need to pass the --flutter-from-path flag down because using the
      // tool will automatically select the one that's running the VM and we'll
      // have selected that here.
      FlutterSdk.current.dartExePath,
      [toolPath, ...args],
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
      stderr: processStderr.toString(),
    );
  }

  /// Runs [commands] in serial, from [workingDirectory].
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

Future<Process> startIndependentProcess(
  CliCommand command, {
  String? workingDirectory,
  String? waitForOutput,
  Duration waitForOutputTimeout = const Duration(minutes: 2),
  void Function(String line)? onOutput,
}) async {
  final commandDisplay = '${workingDirectory ?? ''} > $command';
  print(commandDisplay);
  final process = await Process.start(
    command.exe,
    command.args,
    workingDirectory: workingDirectory,
  );

  if (waitForOutput != null) {
    final completer = Completer<void>();
    final stdoutSub = process.stdout.transform(utf8.decoder).listen((line) {
      print('> [stdout] $line');
      onOutput?.call(line);
      if (line.contains(waitForOutput)) {
        completer.complete();
      }
    });
    final stderrSub = process.stderr.transform(utf8.decoder).listen((line) {
      print('> [stderr] $line');
      onOutput?.call(line);
      if (line.contains(waitForOutput)) {
        completer.complete();
      }
    });
    await completer.future.timeout(
      waitForOutputTimeout,
      onTimeout: () {
        throw Exception(
          'Expected output "$waitForOutput" not received before timeout.',
        );
      },
    );
    await stdoutSub.cancel();
    await stderrSub.cancel();
  }

  return process;
}

String pathFromRepoRoot(String pathFromRoot) {
  return path.join(DevToolsRepo.getInstance().repoPath, pathFromRoot);
}

/// Returns the name of the git remote with id [remoteId] in
/// [workingDirectory].
///
/// When [workingDirectory] is `null`, this method will look for the remote in
/// the current directory.
///
/// [remoteId] should have the form `<organization>/<repository>.git`.
/// For example: `'flutter/flutter.git'` or `'flutter/devtools.git'`.
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
