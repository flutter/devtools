// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_shared/src/deeplink/deeplink_manager.dart';
import 'package:test/test.dart';

void main() {
  group('DeeplinkManager', () {
    late StubbedDeeplinkManager manager;
    late Directory tmpDir;

    setUp(() {
      DeeplinkManager.clearBuildOptionsCache();
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
          arguments: <String>['analyze', '--android', '--list-build-variants'],
          workingDirectory: projectRoot,
          result: ProcessResult(0, 0, r'''
Running Gradle task 'printBuildVariants'...                        10.4s
["debug","release","profile"]
            ''', ''),
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
      'getBuildVariants propagates parent IDE and analytics opt-out status',
      () async {
        const projectRoot = '/abc';
        manager.expectedCommands.add(
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--android',
              '--list-build-variants',
            ],
            workingDirectory: projectRoot,
            ide: 'VS-Code',
            suppressAnalytics: true,
            result: ProcessResult(0, 0, r'''
Running Gradle task 'printBuildVariants'...                        10.4s
["debug"]
            ''', ''),
          ),
        );
        final response = await manager.getAndroidBuildVariants(
          rootPath: projectRoot,
          ide: 'VS-Code',
          suppressAnalytics: true,
        );
        expect(response[DeeplinkManager.kErrorField], isNull);
        expect(response[DeeplinkManager.kOutputJsonField], '["debug"]');
      },
    );

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
            ],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 1, '', 'unknown error'),
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
      manager.expectedCommands.addAll([
        TestCommand(
          executable: manager.mockedFlutterBinary,
          arguments: <String>['analyze', '--android', '--list-build-variants'],
          workingDirectory: projectRoot,
          result: ProcessResult(0, 0, '''
Running Gradle task 'printBuildVariants'...                        10.4s
["$buildVariant"]
            ''', ''),
        ),
        TestCommand(
          executable: manager.mockedFlutterBinary,
          arguments: <String>[
            'analyze',
            '--android',
            '--output-app-link-settings',
            '--build-variant=$buildVariant',
          ],
          workingDirectory: projectRoot,
          result: ProcessResult(0, 0, '''
Running Gradle task 'printBuildVariants'...                        10.4s
result saved in ${jsonFile.absolute.path}
            ''', ''),
        ),
      ]);
      await manager.getAndroidBuildVariants(rootPath: projectRoot);
      final response = await manager.getAndroidAppLinkSettings(
        buildVariant: buildVariant,
        rootPath: projectRoot,
      );
      expect(response[DeeplinkManager.kErrorField], isNull);
      expect(response[DeeplinkManager.kOutputJsonField], json);
    });

    test(
      'getAndroidAppLinkSettings reuses cached variants across instances',
      () async {
        const projectRoot = '/abc';
        const json = '"some json"';
        const buildVariant = 'release';
        final jsonFile = File('${tmpDir.path}/some-output.json');
        jsonFile.writeAsStringSync(json);

        manager.expectedCommands.add(
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--android',
              '--list-build-variants',
            ],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, '''
Running Gradle task 'printBuildVariants'...                        10.4s
["debug","release","profile"]
            ''', ''),
          ),
        );
        await manager.getAndroidBuildVariants(rootPath: projectRoot);

        final secondManager = StubbedDeeplinkManager()
          ..expectedCommands.add(
            TestCommand(
              executable: manager.mockedFlutterBinary,
              arguments: <String>[
                'analyze',
                '--android',
                '--output-app-link-settings',
                '--build-variant=$buildVariant',
              ],
              workingDirectory: '$projectRoot/',
              result: ProcessResult(0, 0, '''
Running Gradle task 'printBuildVariants'...                        10.4s
result saved in ${jsonFile.absolute.path}
            ''', ''),
            ),
          );
        final response = await secondManager.getAndroidAppLinkSettings(
          buildVariant: buildVariant,
          rootPath: '$projectRoot/',
        );
        expect(secondManager.expectedCommands, isEmpty);
        expect(response[DeeplinkManager.kErrorField], isNull);
        expect(response[DeeplinkManager.kOutputJsonField], json);
      },
    );

    test(
      'getIosUniversalLinkSettings calls flutter command correctly',
      () async {
        const projectRoot = '/abc';
        const json = '"some json"';
        const configuration = 'someConfig';
        const target = 'someTarget';
        final jsonFile = File('${tmpDir.path}/some-output.json');
        jsonFile.writeAsStringSync(json);
        manager.expectedCommands.addAll([
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>['analyze', '--ios', '--list-build-options'],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, '''
{"configurations":["$configuration"],"targets":["$target"]}
            ''', ''),
          ),
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--ios',
              '--output-universal-link-settings',
              '--configuration=$configuration',
              '--target=$target',
            ],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, '''
Running Gradle task 'printBuildVariants'...                        10.4s
result saved in ${jsonFile.absolute.path}
            ''', ''),
          ),
        ]);
        await manager.getIosBuildOptions(rootPath: projectRoot);
        final response = await manager.getIosUniversalLinkSettings(
          configuration: configuration,
          target: target,
          rootPath: projectRoot,
        );
        expect(response[DeeplinkManager.kErrorField], isNull);
        expect(response[DeeplinkManager.kOutputJsonField], json);
      },
    );

    test('getIosBuildOptions calls flutter command correctly', () async {
      const projectRoot = '/abc';
      manager.expectedCommands.add(
        TestCommand(
          executable: manager.mockedFlutterBinary,
          arguments: <String>['analyze', '--ios', '--list-build-options'],
          workingDirectory: projectRoot,
          result: ProcessResult(0, 0, r'''
{"configurations":["Debug","Release","Profile"],"targets":["Runner","RunnerTests"]}
            ''', ''),
        ),
      );
      final response = await manager.getIosBuildOptions(rootPath: projectRoot);
      expect(response[DeeplinkManager.kErrorField], isNull);
      expect(
        response[DeeplinkManager.kOutputJsonField],
        '{"configurations":["Debug","Release","Profile"],"targets":["Runner","RunnerTests"]}',
      );
    });

    test(
      'returns error when project build options have not been parsed yet',
      () async {
        const projectRoot = '/unparsed_project';
        final androidResponse = await manager.getAndroidAppLinkSettings(
          rootPath: projectRoot,
          buildVariant: 'debug',
        );
        expect(
          androidResponse[DeeplinkManager.kErrorField],
          allOf(
            contains('have not been parsed yet'),
            contains('https://github.com/flutter/devtools/issues'),
          ),
        );

        final iosResponse = await manager.getIosUniversalLinkSettings(
          rootPath: projectRoot,
          configuration: 'Debug',
          target: 'Runner',
        );
        expect(
          iosResponse[DeeplinkManager.kErrorField],
          allOf(
            contains('have not been parsed yet'),
            contains('https://github.com/flutter/devtools/issues'),
          ),
        );
      },
    );

    test(
      'rejects buildVariant not in available Android build variants',
      () async {
        const projectRoot = '/abc';
        manager.expectedCommands.add(
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--android',
              '--list-build-variants',
            ],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, r'''
Running Gradle task 'printBuildVariants'...                        10.4s
["debug","release","profile"]
            ''', ''),
          ),
        );
        await manager.getAndroidBuildVariants(rootPath: projectRoot);

        for (final invalidVariant in <String>[
          'nonExistentVariant',
          '"& calc & echo pwned > MARKER.txt &"',
          'debug --help',
        ]) {
          final response = await manager.getAndroidAppLinkSettings(
            rootPath: projectRoot,
            buildVariant: invalidVariant,
          );
          expect(
            response[DeeplinkManager.kErrorField],
            allOf(
              contains('Unknown Android build variant'),
              contains('https://github.com/flutter/devtools/issues'),
            ),
          );
        }
      },
    );

    test(
      'rejects configuration or target not in available iOS build options',
      () async {
        const projectRoot = '/abc';
        manager.expectedCommands.add(
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>['analyze', '--ios', '--list-build-options'],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, r'''
{"configurations":["Debug","Release","Profile"],"targets":["Runner","RunnerTests"]}
            ''', ''),
          ),
        );
        await manager.getIosBuildOptions(rootPath: projectRoot);

        final badConfigResponse = await manager.getIosUniversalLinkSettings(
          rootPath: projectRoot,
          configuration: '"& calc & echo pwned > MARKER.txt &"',
          target: 'Runner',
        );
        expect(
          badConfigResponse[DeeplinkManager.kErrorField],
          allOf(
            contains('Unknown iOS build configuration'),
            contains('https://github.com/flutter/devtools/issues'),
          ),
        );

        final badTargetResponse = await manager.getIosUniversalLinkSettings(
          rootPath: projectRoot,
          configuration: 'Debug',
          target: 'Runner --help',
        );
        expect(
          badTargetResponse[DeeplinkManager.kErrorField],
          allOf(
            contains('Unknown iOS build configuration'),
            contains('https://github.com/flutter/devtools/issues'),
          ),
        );
      },
    );

    test('returns error when workingDirectory does not exist', () async {
      final realManager = DeeplinkManager();
      final response = await realManager.getAndroidBuildVariants(
        rootPath: '${tmpDir.path}/non_existent_dir_"&calc',
      );
      expect(response[DeeplinkManager.kErrorField], isNotNull);
    });

    test(
      'returns error when parsing Android build variants or iOS build options fails',
      () async {
        const projectRoot = '/abc';
        manager.expectedCommands.addAll([
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>[
              'analyze',
              '--android',
              '--list-build-variants',
            ],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, '[invalid json]', ''),
          ),
          TestCommand(
            executable: manager.mockedFlutterBinary,
            arguments: <String>['analyze', '--ios', '--list-build-options'],
            workingDirectory: projectRoot,
            result: ProcessResult(0, 0, '{invalid json}', ''),
          ),
        ]);

        final androidResponse = await manager.getAndroidBuildVariants(
          rootPath: projectRoot,
        );
        expect(
          androidResponse[DeeplinkManager.kErrorField],
          contains('Failed to parse Android build variants'),
        );

        final iosResponse = await manager.getIosBuildOptions(
          rootPath: projectRoot,
        );
        expect(
          iosResponse[DeeplinkManager.kErrorField],
          contains('Failed to parse iOS build options'),
        );
      },
    );
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
    required String workingDirectory,
    required String? ide,
    required bool suppressAnalytics,
  }) async {
    if (expectedCommands.isNotEmpty) {
      final expectedCommand = expectedCommands.removeAt(0);
      expect(executable, expectedCommand.executable);
      expect(
        const ListEquality<String>().equals(
          arguments,
          expectedCommand.arguments,
        ),
        isTrue,
      );
      expect(workingDirectory, expectedCommand.workingDirectory);
      expect(ide, expectedCommand.ide);
      expect(suppressAnalytics, expectedCommand.suppressAnalytics);
      return expectedCommand.result;
    }
    throw 'Received unexpected command: $executable ${arguments.join(' ')}';
  }
}

class TestCommand {
  const TestCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    this.ide,
    this.suppressAnalytics = false,
    required this.result,
  });
  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final String? ide;
  final bool suppressAnalytics;
  final ProcessResult result;

  @override
  String toString() {
    return '"$executable ${arguments.join(' ')}" (workingDirectory: $workingDirectory)';
  }
}
