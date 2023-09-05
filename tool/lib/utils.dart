// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:io/io.dart';

String convertProcessOutputToString(List<List<int>> output, String indent) {
  String result = output.map((codes) => utf8.decode(codes)).join();
  result = result.trim();
  result = result
      .split('\n')
      .where((line) => line.isNotEmpty)
      .map((line) => '$indent$line')
      .join('\n');
  return result;
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

  late final String exe;
  late final List<String> args;
  final bool throwOnException;
}

Future<void> runProcess(
  ProcessManager processManager,
  CliCommand command, {
  String? workingDirectory,
  String? additionalErrorMessage = '',
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
      'Failed with exit code: $code. $additionalErrorMessage',
      code,
    );
  }
}

Future<void> runAll(
  ProcessManager processManager, {
  required List<CliCommand> commands,
  String? workingDirectory,
  String? additionalErrorMessage = '',
}) async {
  for (final command in commands) {
    await runProcess(
      processManager,
      command,
      workingDirectory: workingDirectory,
      additionalErrorMessage: additionalErrorMessage,
    );
  }
}
