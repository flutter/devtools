// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:test/test.dart';

void main() {
  group('DeeplinkManager', () {
    late StubbedDeeplinkManager manager;
    setUp(() {
      manager = StubbedDeeplinkManager();
    });

    tearDown(() {
      expect(manager.expectedCommands.isEmpty, true,
          reason:
              'stub does not receive expected command ${manager.expectedCommands}');
    });

    test('getBuildVariants calls flutter command correctly', () async {
      const String projectRoot = '/abc';
      manager.expectedCommands.add(
        TestCommand(
          executable: 'flutter',
          arguments: <String>[
            'analyze',
            '--android',
            '--list-build-variants',
            projectRoot
          ],
          result: ProcessResult(
            0,
            0,
            '["release", "profile"]',
            '',
          ),
        ),
      );
      final response = await manager.getBuildVariants(
          rootPath: projectRoot, api: ServerApi());
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), '["release", "profile"]');
    });

    test('getBuildVariants return internal server error if command failed',
        () async {
      const String projectRoot = '/abc';
      manager.expectedCommands.add(
        TestCommand(
          executable: 'flutter',
          arguments: <String>[
            'analyze',
            '--android',
            '--list-build-variants',
            projectRoot
          ],
          result: ProcessResult(
            0,
            1,
            '',
            'unknown error',
          ),
        ),
      );
      final response = await manager.getBuildVariants(
          rootPath: projectRoot, api: ServerApi());
      expect(response.statusCode, HttpStatus.internalServerError);
    });
  });
}

class StubbedDeeplinkManager extends DeeplinkManager {
  final List<TestCommand> expectedCommands = <TestCommand>[];
  @override
  Future<ProcessResult> runProcess(
      String executable, List<String> arguments) async {
    if (expectedCommands.isNotEmpty) {
      final TestCommand expectedCommand = expectedCommands.removeAt(0);
      expect(expectedCommand.executable, executable);
      expect(
          const ListEquality<String>()
              .equals(expectedCommand.arguments, arguments),
          isTrue);
      return expectedCommand.result;
    }
    throw 'Received unexpected command: $executable ${arguments.join(' ')}';
  }
}

class TestCommand {
  const TestCommand({
    required this.executable,
    required this.arguments,
    required this.result,
  });
  final String executable;
  final List<String> arguments;
  final ProcessResult result;

  @override
  String toString() {
    return '"$executable ${arguments.join(' ')}"';
  }
}
