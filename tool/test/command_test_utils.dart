// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';

class MockProcessManager implements ProcessManager {
  MockProcessManager({this.onSpawn});

  final Future<Process> Function(
    String executable,
    Iterable<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment,
    bool runInShell,
    ProcessStartMode mode,
  })?
  onSpawn;

  @override
  Future<Process> spawn(
    String executable,
    Iterable<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    if (onSpawn != null) {
      return onSpawn!(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        mode: mode,
      );
    }
    return MockProcess();
  }

  @override
  Future<Process> spawnBackground(
    String executable,
    Iterable<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Process> spawnDetached(
    String executable,
    Iterable<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    throw UnimplementedError();
  }
}

class MockProcess implements Process {
  MockProcess({
    this.exitCodeValue = 0,
    this.stdoutString = '',
    this.stderrString = '',
  });

  final int exitCodeValue;
  final String stdoutString;
  final String stderrString;

  @override
  Future<int> get exitCode => Future.value(exitCodeValue);

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(stdoutString));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(stderrString));

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 0;

  @override
  IOSink get stdin => throw UnimplementedError();
}

class TestCommandRunner extends CommandRunner {
  TestCommandRunner() : super('test', 'test description');

  void addDummyCommand(String name, [int exitCode = 0]) {
    addCommand(DummyCommand(name, exitCode));
  }
}

class DummyCommand extends Command {
  DummyCommand(this.name, this.exitCodeValue);

  @override
  final String name;

  @override
  String get description => 'Dummy command for testing';

  final int exitCodeValue;

  @override
  Future<int> run() async => exitCodeValue;
}
