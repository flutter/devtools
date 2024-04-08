// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:dtd/dtd.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

const projectRootParts = ['absolute_path_to', 'my_app_root'];
late String projectRoot;

late File libFile;
late File libSubFile;
late File binFile;
late File binSubFile;
late File testFile;
late File testSubFile;
late File integrationTestFile;
late File integrationTestSubFile;
late File benchmarkFile;
late File benchmarkSubFile;
late File exampleFile;
late File exampleSubFile;
late File anyFile;
late File anySubFile;

void main() {
  group('file uri helpers', () {
    TestDtdConnectionInfo? dtd;
    DartToolingDaemon? testDtdConnection;

    setUp(() async {
      dtd = await startDtd();
      expect(dtd!.uri, isNotNull, reason: 'Error starting DTD for test');
      testDtdConnection = await DartToolingDaemon.connect(Uri.parse(dtd!.uri!));

      _setupTestDirectoryStructure();

      await testDtdConnection!.setIDEWorkspaceRoots(
        dtd!.secret!,
        [Uri.parse(projectRoot)],
      );
    });

    tearDown(() async {
      await testDtdConnection?.close();
      dtd?.dtdProcess?.kill();
      await dtd?.dtdProcess?.exitCode;
      dtd = null;
    });

    Future<void> verifyPackageRoot(
      String fileUriString, {
      required bool useDtd,
      String? expected,
    }) async {
      final result = await packageRootFromFileUriString(
        fileUriString,
        dtd: useDtd ? testDtdConnection! : null,
        throwOnDtdSearchFailed: useDtd,
      );
      expect(result, equals(expected ?? projectRoot));
    }

    test('packageRootFromFileUriString throw exception for invalid input', () {
      expect(
        () async {
          await packageRootFromFileUriString('/not/a/valid/file/uri');
        },
        throwsA(isA<AssertionError>()),
      );
    });

    for (final useDtd in const [true, false]) {
      test(
        'packageRootFromFileUriString${useDtd ? ' using DTD' : ''}',
        () async {
          // Dart file under 'lib'
          await verifyPackageRoot(libFile.uri.toString(), useDtd: useDtd);
          await verifyPackageRoot(libSubFile.uri.toString(), useDtd: useDtd);

          // Dart file under 'bin'
          await verifyPackageRoot(binFile.uri.toString(), useDtd: useDtd);
          await verifyPackageRoot(binSubFile.uri.toString(), useDtd: useDtd);

          // Dart file under 'test'
          await verifyPackageRoot(testFile.uri.toString(), useDtd: useDtd);
          await verifyPackageRoot(testSubFile.uri.toString(), useDtd: useDtd);

          // Dart file under 'integration_test'
          await verifyPackageRoot(
            integrationTestFile.uri.toString(),
            useDtd: useDtd,
          );
          await verifyPackageRoot(
            integrationTestSubFile.uri.toString(),
            useDtd: useDtd,
          );

          // Dart file under 'benchmark'
          await verifyPackageRoot(
            benchmarkFile.uri.toString(),
            useDtd: useDtd,
          );
          await verifyPackageRoot(
            benchmarkSubFile.uri.toString(),
            useDtd: useDtd,
          );

          // Dart file under 'example'
          await verifyPackageRoot(exampleFile.uri.toString(), useDtd: useDtd);
          await verifyPackageRoot(
            exampleSubFile.uri.toString(),
            useDtd: useDtd,
          );

          // Dart file under an unknown directory.
          await verifyPackageRoot(
            anyFile.uri.toString(),
            expected: useDtd ? projectRoot : anyFile.uri.toString(),
            useDtd: useDtd,
          );
          await verifyPackageRoot(
            anySubFile.uri.toString(),
            expected: useDtd ? projectRoot : anySubFile.uri.toString(),
            useDtd: useDtd,
          );
        },
      );
    }
  });
}

/// Sets up the directory structure for each test.
///
/// Test directory structure:
/// my_app_root/
///   .dart_tool/
///   any_name/
///     foo.dart
///     sub/
///       foo.dart
///   benchmark/
///     foo.dart
///     sub/
///       foo.dart
///   bin/
///     foo.dart
///     sub/
///       foo.dart
///   example/
///     foo.dart
///     sub/
///       foo.dart
///   integration_test/
///     foo_test.dart
///     sub/
///       foo_test.dart
///   lib/
///     foo.dart
///     sub/
///       foo.dart
///   test/
///     foo_test.dart
///     sub/
///       foo_test.dart
void _setupTestDirectoryStructure() {
  final tmpDirectory = Directory.systemTemp.createTempSync();
  final projectRootDirectory =
      Directory(p.joinAll([tmpDirectory.path, ...projectRootParts]))
        ..createSync(recursive: true);
  final directoryPath =
      Uri.file(projectRootDirectory.uri.toFilePath()).toString();

  // Remove the trailing slash and set the value of [projectRoot].
  projectRoot = directoryPath.substring(0, directoryPath.length - 1);

  // Set up the project root contents.
  Directory(p.join(projectRootDirectory.path, '.dart_tool'))
      .createSync(recursive: true);
  libFile = File(p.join(projectRootDirectory.path, 'lib', 'foo.dart'))
    ..createSync(recursive: true);
  libSubFile = File(p.join(projectRootDirectory.path, 'lib', 'sub', 'foo.dart'))
    ..createSync(recursive: true);
  binFile = File(p.join(projectRootDirectory.path, 'bin', 'foo.dart'))
    ..createSync(recursive: true);
  binSubFile = File(p.join(projectRootDirectory.path, 'bin', 'sub', 'foo.dart'))
    ..createSync(recursive: true);
  testFile = File(p.join(projectRootDirectory.path, 'test', 'foo_test.dart'))
    ..createSync(recursive: true);
  testSubFile = File(
    p.join(projectRootDirectory.path, 'test', 'sub', 'foo_test.dart'),
  )..createSync(recursive: true);
  integrationTestFile = File(
    p.join(projectRootDirectory.path, 'integration_test', 'foo_test.dart'),
  )..createSync(recursive: true);
  integrationTestSubFile = File(
    p.join(
      projectRootDirectory.path,
      'integration_test',
      'sub',
      'foo_test.dart',
    ),
  )..createSync(recursive: true);
  benchmarkFile =
      File(p.join(projectRootDirectory.path, 'benchmark', 'foo.dart'))
        ..createSync(recursive: true);
  benchmarkSubFile = File(
    p.join(projectRootDirectory.path, 'benchmark', 'sub', 'foo.dart'),
  )..createSync(recursive: true);
  exampleFile = File(p.join(projectRootDirectory.path, 'example', 'foo.dart'))
    ..createSync(recursive: true);
  exampleSubFile =
      File(p.join(projectRootDirectory.path, 'example', 'sub', 'foo.dart'))
        ..createSync(recursive: true);
  anyFile = File(p.join(projectRootDirectory.path, 'any_name', 'foo.dart'))
    ..createSync(recursive: true);
  anySubFile =
      File(p.join(projectRootDirectory.path, 'any_name', 'sub', 'foo.dart'))
        ..createSync(recursive: true);
}
