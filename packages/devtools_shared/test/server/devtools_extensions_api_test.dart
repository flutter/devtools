// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../fakes.dart';
import '../helpers.dart';

late Directory testDirectory;
late String projectRoot;

void main() {
  late ExtensionsManager extensionsManager;

  group(ExtensionsApi.apiServeAvailableExtensions, () {
    setUp(() {
      extensionsManager = ExtensionsManager();
    });

    tearDown(() async {
      // Run with retry to ensure this deletes properly on Windows.
      await deleteDirectoryWithRetry(testDirectory);
    });

    test('succeeds for valid extensions', () async {
      await _setupTestDirectoryStructure();
      final request = Request(
        'post',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: ExtensionsApi.apiServeAvailableExtensions,
          queryParameters: {
            ExtensionsApi.extensionRootPathPropertyName: projectRoot,
          },
        ),
      );
      final response = await ServerApi.handle(
        request,
        extensionsManager: extensionsManager,
        deeplinkManager: FakeDeeplinkManager(),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(extensionsManager.devtoolsExtensions.length, 2);
      expect(extensionsManager.devtoolsExtensions[0].name, 'drift');
      expect(extensionsManager.devtoolsExtensions[1].name, 'provider');
    });

    test('succeeds with mix of valid and invalid extensions', () async {
      await _setupTestDirectoryStructure(includeBadExtension: true);
      final request = Request(
        'post',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: ExtensionsApi.apiServeAvailableExtensions,
          queryParameters: {
            ExtensionsApi.extensionRootPathPropertyName: projectRoot,
          },
        ),
      );
      final Response response = await ServerApi.handle(
        request,
        extensionsManager: extensionsManager,
        deeplinkManager: FakeDeeplinkManager(),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(extensionsManager.devtoolsExtensions.length, 2);
      expect(extensionsManager.devtoolsExtensions[0].name, 'drift');
      expect(extensionsManager.devtoolsExtensions[1].name, 'provider');

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final warning =
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName];
      expect(
        warning,
        contains('Encountered errors while parsing extension config.yaml'),
      );
    });

    test('succeeds for valid extensions when an exception is thrown', () async {
      await _setupTestDirectoryStructure();
      extensionsManager = _TestExtensionsManager();
      final request = Request(
        'post',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: ExtensionsApi.apiServeAvailableExtensions,
          queryParameters: {
            ExtensionsApi.extensionRootPathPropertyName: projectRoot,
          },
        ),
      );
      final response = await ServerApi.handle(
        request,
        extensionsManager: extensionsManager,
        deeplinkManager: FakeDeeplinkManager(),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(extensionsManager.devtoolsExtensions.length, 2);
      expect(extensionsManager.devtoolsExtensions[0].name, 'drift');
      expect(extensionsManager.devtoolsExtensions[1].name, 'provider');

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final warning =
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName];
      expect(warning, contains('Fake exception for test'));
    });

    test('fails when an exception is thrown and there are no valid extensions',
        () async {
      await _setupTestDirectoryStructure(
        includeDependenciesWithExtensions: false,
      );
      extensionsManager = _TestExtensionsManager();
      final request = Request(
        'post',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: ExtensionsApi.apiServeAvailableExtensions,
          queryParameters: {
            ExtensionsApi.extensionRootPathPropertyName: projectRoot,
          },
        ),
      );
      final response = await ServerApi.handle(
        request,
        extensionsManager: extensionsManager,
        deeplinkManager: FakeDeeplinkManager(),
      );
      expect(response.statusCode, HttpStatus.internalServerError);
      expect(extensionsManager.devtoolsExtensions, isEmpty);

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final error = parsedResponse['error'];
      expect(error, contains('Fake exception for test'));
    });
  });
}

class _TestExtensionsManager extends ExtensionsManager {
  @override
  Future<void> serveAvailableExtensions(
    String? rootFileUriString,
    List<String> logs,
  ) async {
    await super.serveAvailableExtensions(rootFileUriString, logs);
    throw Exception('Fake exception for test');
  }
}

/// my_app/
///   .dart_tool/             # Generated from 'pub get' in this method
///     package_config.json   # Generated from 'pub get' in this method
///   pubspec.yaml
/// bad_extension/            # Only added when [includeBadExtension] is true.
///   extension/
///     devtools/
///       build/
///       config.yaml
Future<void> _setupTestDirectoryStructure({
  bool includeDependenciesWithExtensions = true,
  bool includeBadExtension = false,
}) async {
  testDirectory = Directory.systemTemp.createTempSync();
  final projectRootDirectory = Directory(p.join(testDirectory.path, 'my_app'))
    ..createSync(recursive: true);
  final directoryPath =
      Uri.file(projectRootDirectory.uri.toFilePath()).toString();
  // Remove the trailing slash and set the value of [projectRoot].
  projectRoot = directoryPath.substring(0, directoryPath.length - 1);

  if (includeBadExtension) {
    final badExtensionDirectory =
        Directory(p.join(testDirectory.path, 'bad_extension'))
          ..createSync(recursive: true);
    final extensionDir =
        Directory(p.join(badExtensionDirectory.path, 'extension', 'devtools'))
          ..createSync(recursive: true);
    Directory(p.join(extensionDir.path, 'build')).createSync(recursive: true);
    // Extension names must be only lowercase letters and underscores.
    const invalidConfigFileContent = '''
name: BAD_EXTENSION
issueTracker: https://www.google.com/
version: 1.0.0
materialIconCodePoint: "0xe50a"
''';
    File(p.join(extensionDir.path, 'config.yaml'))
      ..createSync()
      ..writeAsStringSync(invalidConfigFileContent, flush: true);

    File(p.join(badExtensionDirectory.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '''
name: bad_extension
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
''',
        flush: true,
      );
  }

  final dependenciesWithExtensions = includeDependenciesWithExtensions
      ? '''
  # packages with published DevTools extensions.
  drift: 2.16.0
  provider: 6.1.2
'''
      : '';
  final badExtensionDependency = includeBadExtension
      ? '''
  bad_extension:
    path: ../bad_extension
'''
      : '';
  File(p.join(projectRootDirectory.path, 'pubspec.yaml'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '''
name: my_app
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:
$dependenciesWithExtensions
$badExtensionDependency
''',
      flush: true,
    );

  // Run `dart pub get` on this package to generate the
  // `.dart_tool/package_config.json` file.
  await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: projectRootDirectory.path,
  );

  final packageConfigFile = File(
    p.join(projectRootDirectory.path, '.dart_tool', 'package_config.json'),
  );
  expect(packageConfigFile.existsSync(), isTrue);
}
