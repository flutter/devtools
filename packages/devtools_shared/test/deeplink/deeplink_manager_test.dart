// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';
import 'package:test/test.dart';

void main() {
  group('DeeplinkManager', () {
    late StubbedDeeplinkManager manager;
    late Directory tmpDir;

    setUp(() {
      manager = StubbedDeeplinkManager();
      tmpDir = Directory.current.createTempSync();
    });

    tearDown(() {
      expect(
        manager.expectedCommands.isEmpty,
        true,
        reason:
            'stub does not receive expected command ${manager.expectedCommands}',
      );
      tmpDir.deleteSync(recursive: true);
    });

    test('getBuildVariants calls flutter command correctly', () async {
      const projectRoot = '/abc';
      manager.expectedCommands.add(
        TestCommand(
          executable: manager.mockedFlutterBinary,
          arguments: <String>[
            'analyze',
            '--android',
            '--list-build-variants',
            projectRoot,
          ],
          result: ProcessResult(
            0,
            0,
            r'''
Running Gradle task 'printBuildVariants'...                        10.4s
["debug","release","profile"]
            ''',
            '',
          ),
        ),
      );
      final response = await manager.getAndroidBuildVariants(
        rootPath: projectRoot,
      );
      expect(response[DeeplinkManager.kErrorField], isNull);
      expect(
        response[DeeplinkManager.kOutputJsonField],
        '["debug","release","profile"]',
      );
    });

    test(
      'getBuildVariants return internal server error if command failed',
      () async {
        const projectRoot = '/abc';
        manager.expectedCommands.add(
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--android',
              '--list-build-variants',
              projectRoot,
            ],
            result: ProcessResult(
              0,
              1,
              '',
              'unknown error',
            ),
          ),
        );
        final response = await manager.getAndroidBuildVariants(
          rootPath: projectRoot,
        );
        expect(
          response[DeeplinkManager.kErrorField],
          contains('unknown error'),
        );
      },
    );

    test('getAndroidAppLinkSettings calls flutter command correctly', () async {
      const projectRoot = '/abc';
      const json = '"some json"';
      const buildVariant = 'someVariant';
      final jsonFile = File('${tmpDir.path}/some-output.json');
      jsonFile.writeAsStringSync(json);
      manager.expectedCommands.add(
        TestCommand(
          executable: manager.mockedFlutterBinary,
          arguments: <String>[
            'analyze',
            '--android',
            '--output-app-link-settings',
            '--build-variant=$buildVariant',
            projectRoot,
          ],
          result: ProcessResult(
            0,
            0,
            '''
Running Gradle task 'printBuildVariants'...                        10.4s
result saved in ${jsonFile.absolute.path}
            ''',
            '',
          ),
        ),
      );
      final response = await manager.getAndroidAppLinkSettings(
        buildVariant: buildVariant,
        rootPath: projectRoot,
      );
      expect(response[DeeplinkManager.kErrorField], isNull);
      expect(
        response[DeeplinkManager.kOutputJsonField],
        json,
      );
    });

    test(
      'getIosUniversalLinkSettings calls flutter command correctly',
      () async {
        const projectRoot = '/abc';
        const json = '"some json"';
        const configuration = 'someConfig';
        const target = 'someTarget';
        final jsonFile = File('${tmpDir.path}/some-output.json');
        jsonFile.writeAsStringSync(json);
        manager.expectedCommands.add(
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--ios',
              '--output-universal-link-settings',
              '--configuration=$configuration',
              '--target=$target',
              projectRoot,
            ],
            result: ProcessResult(
              0,
              0,
              '''
Running Gradle task 'printBuildVariants'...                        10.4s
result saved in ${jsonFile.absolute.path}
            ''',
              '',
            ),
          ),
        );
        final response = await manager.getIosUniversalLinkSettings(
          configuration: configuration,
          target: target,
          rootPath: projectRoot,
        );
        expect(response[DeeplinkManager.kErrorField], isNull);
        expect(
          response[DeeplinkManager.kOutputJsonField],
          json,
        );
      },
    );

    test('getIosBuildOptions calls flutter command correctly', () async {
      const projectRoot = '/abc';
      manager.expectedCommands.add(
        TestCommand(
          executable: manager.mockedFlutterBinary,
          arguments: <String>[
            'analyze',
            '--ios',
            '--list-build-options',
            projectRoot,
          ],
          result: ProcessResult(
            0,
            0,
            r'''
{"configurations":["Debug","Release","Profile"],"targets":["Runner","RunnerTests"]}
            ''',
            '',
          ),
        ),
      );
      final response = await manager.getIosBuildOptions(
        rootPath: projectRoot,
      );
      expect(response[DeeplinkManager.kErrorField], isNull);
      expect(
        response[DeeplinkManager.kOutputJsonField],
        '{"configurations":["Debug","Release","Profile"],"targets":["Runner","RunnerTests"]}',
      );
    });
  });
}

class StubbedDeeplinkManager extends DeeplinkManager {
  final expectedCommands = <TestCommand>[];
  String mockedFlutterBinary = 'somebinary';

  @override
  String getFlutterBinary() => mockedFlutterBinary;

  @override
  Future<ProcessResult> runProcess(
    String executable, {
    required List<String> arguments,
  }) async {
    if (expectedCommands.isNotEmpty) {
      final expectedCommand = expectedCommands.removeAt(0);
      expect(expectedCommand.executable, executable);
      expect(
        const ListEquality<String>()
            .equals(expectedCommand.arguments, arguments),
        isTrue,
      );
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
