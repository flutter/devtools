// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:devtools_tool/commands/presubmit.dart';
import 'package:devtools_tool/model.dart';
import 'package:test/test.dart';

import 'command_test_utils.dart';

void main() {
  group('PresubmitCommand', () {
    setUp(() {
      try {
        FlutterSdk.useFromCurrentVm();
      } catch (_) {
        FlutterSdk.useFromPathEnvironmentVariable();
      }
    });

    test('succeeds when all steps pass', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get');
      runner.addDummyCommand('repo-check');
      runner.addDummyCommand('analyze');
      runner.addCommand(PresubmitCommand(processManager: MockProcessManager()));

      final result = await runner.run(['presubmit']);
      expect(result, equals(0));
    });

    test('runs fix and format when --fix is passed', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get');
      runner.addDummyCommand('repo-check');
      runner.addDummyCommand('analyze');

      final capturedArgs = <List<String>>[];
      final mockPm = MockProcessManager(
        onSpawn: (
          executable,
          arguments, {
          workingDirectory,
          environment,
          includeParentEnvironment = true,
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          capturedArgs.add(arguments.toList());
          return MockProcess();
        },
      );

      runner.addCommand(PresubmitCommand(processManager: mockPm));

      final result = await runner.run(['presubmit', '--fix']);
      expect(result, equals(0));

      final hasFix = capturedArgs.any((args) => args.contains('fix'));
      expect(hasFix, isTrue);

      final formatArgs = capturedArgs.firstWhere(
        (args) => args.contains('format'),
        orElse: () => [],
      );
      expect(formatArgs, isNotEmpty);
      expect(formatArgs.contains('--output=none'), isFalse);
      expect(formatArgs.contains('--set-exit-if-changed'), isFalse);
    });

    test('fails fast if pub-get fails', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get', 1); // fails
      runner.addDummyCommand('repo-check');
      runner.addDummyCommand('analyze');
      runner.addCommand(PresubmitCommand(processManager: MockProcessManager()));

      final result = await runner.run(['presubmit']);
      expect(result, equals(1));
    });

    test('fails fast if repo-check fails', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get');
      runner.addDummyCommand('repo-check', 1); // fails
      runner.addDummyCommand('analyze');
      runner.addCommand(PresubmitCommand(processManager: MockProcessManager()));

      final result = await runner.run(['presubmit']);
      expect(result, equals(1));
    });

    test('fails fast if analyze fails', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get');
      runner.addDummyCommand('repo-check');
      runner.addDummyCommand('analyze', 1); // fails
      runner.addCommand(PresubmitCommand(processManager: MockProcessManager()));

      final result = await runner.run(['presubmit']);
      expect(result, equals(1));
    });

    test('fails if dart format check fails without --fix', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get');
      runner.addDummyCommand('repo-check');
      runner.addDummyCommand('analyze');

      final mockPm = MockProcessManager(
        onSpawn: (
          executable,
          arguments, {
          workingDirectory,
          environment,
          includeParentEnvironment = true,
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          if (arguments.contains('format') &&
              arguments.contains('--set-exit-if-changed')) {
            return MockProcess(exitCodeValue: 1);
          }
          return MockProcess();
        },
      );

      runner.addCommand(PresubmitCommand(processManager: mockPm));

      final result = await runner.run(['presubmit']);
      expect(result, equals(1));
    });

    test('filters files for tool package formatting', () async {
      final runner = TestCommandRunner();
      runner.addDummyCommand('pub-get');
      runner.addDummyCommand('repo-check');
      runner.addDummyCommand('analyze');

      final capturedArgs = <List<String>>[];
      final mockPm = MockProcessManager(
        onSpawn: (
          executable,
          arguments, {
          workingDirectory,
          environment,
          includeParentEnvironment = true,
          runInShell = false,
          mode = ProcessStartMode.normal,
        }) async {
          capturedArgs.add(arguments.toList());
          return MockProcess();
        },
      );

      runner.addCommand(PresubmitCommand(processManager: mockPm));

      await runner.run(['presubmit']);

      // Find the format command for the tool package.
      // It should contain 'lib' (since 'lib' is one of its children) and NOT
      // '.' (which is used for other packages). Or it should contain multiple
      // paths.
      final toolFormatArgs = capturedArgs.firstWhere(
        // 'dart', 'format', and at least two paths
        (args) => args.contains('format') && args.length > 3,
        orElse: () => [],
      );

      expect(toolFormatArgs, isNotEmpty);
      expect(toolFormatArgs.contains('flutter-sdk'), isFalse);
    });
  });
}
