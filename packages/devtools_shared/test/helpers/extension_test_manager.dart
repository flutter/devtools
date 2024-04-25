// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

class ExtensionTestManager {
  /// The Directory for this test.
  ///
  /// This should be created and destroyed for each test.
  Directory get testDirectory => _testDirectory!;
  Directory? _testDirectory;

  /// The `file://` URI for the directory containing the Dart packages we will
  /// detect extensions for.
  Uri get packagesRootUri => _packagesRootUri!;
  Uri? _packagesRootUri;

  /// The `file://` URI string for the package root of the app that we may
  /// consider DevTools connected to for testing the extension APIs.
  String get runtimeAppRoot => _runtimeAppRoot!;
  String? _runtimeAppRoot;

  Future<void> reset() async {
    // Run with retry to ensure this deletes properly on Windows.
    await deleteDirectoryWithRetry(testDirectory);
    _testDirectory = null;
    _packagesRootUri = null;
    _runtimeAppRoot = null;
  }

  /// packages/
  ///   my_app/
  ///     .dart_tool/             # Generated from 'pub get'
  ///       package_config.json   # Generated from 'pub get'
  ///     pubspec.yaml
  ///   other_root_1/
  ///     .dart_tool/             # Generated from 'pub get'
  ///       package_config.json   # Generated from 'pub get'
  ///     pubspec.yaml
  ///   other_root_2/
  ///     .dart_tool/             # Generated from 'pub get'
  ///       package_config.json   # Generated from 'pub get'
  ///     pubspec.yaml
  /// extensions/
  ///   static_extension_1/
  ///     extension/
  ///       devtools/
  ///         build/
  ///         config.yaml
  ///     pubspec.yaml
  ///   static_extension_2/
  ///     extension/
  ///       devtools/
  ///         build/
  ///         config.yaml
  ///     pubspec.yaml
  ///   newer/
  ///     static_extension_1/
  ///       extension/
  ///         devtools/
  ///           build/
  ///           config.yaml
  ///       pubspec.yaml
  ///   bad_extension/            # Only added when [includeBadExtension] is true.
  ///     extension/
  ///       devtools/
  ///         build/
  ///         config.yaml
  ///     pubspec.yaml
  Future<void> setupTestDirectoryStructure({
    bool includeDependenciesWithExtensions = true,
    bool includeBadExtension = false,
  }) async {
    _testDirectory = Directory.systemTemp.createTempSync();

    _setupPackages(
      includeDependenciesWithExtensions: includeDependenciesWithExtensions,
      includeBadExtension: includeBadExtension,
    );
    _setupExtensions(includeBadExtension: includeBadExtension);

    // Generate the .dart_tool/package_config.json file for each Dart package.
    final testDirectoryContents = testDirectory.listSync();
    expect(testDirectoryContents.length, 2);
    final packageRoots =
        Directory.fromUri(packagesRootUri).listSync().whereType<Directory>();
    expect(packageRoots.length, 3);

    for (final packageRoot in packageRoots) {
      expect(File(p.join(packageRoot.path, 'pubspec.yaml')).existsSync(), true);

      // Run `dart pub get` on this package to generate the
      // `.dart_tool/package_config.json` file.
      final process = await Process.run(
        Platform.resolvedExecutable,
        ['pub', 'get'],
        workingDirectory: packageRoot.path,
      );
      if (process.exitCode != 0) {
        throw Exception(
          'Encountered error while running pub get. Exit code: '
          '${process.exitCode}, error: ${process.stderr}.',
        );
      }

      final packageConfigFile = File(
        p.join(packageRoot.path, '.dart_tool', 'package_config.json'),
      );
      expect(packageConfigFile.existsSync(), isTrue);
    }
  }

  /// packages/
  ///   my_app/
  ///     .dart_tool/             # Generated from 'pub get'
  ///       package_config.json   # Generated from 'pub get'
  ///     pubspec.yaml
  ///   other_root_1/
  ///     .dart_tool/             # Generated from 'pub get'
  ///       package_config.json   # Generated from 'pub get'
  ///     pubspec.yaml
  ///   other_root_2/
  ///     .dart_tool/             # Generated from 'pub get'
  ///       package_config.json   # Generated from 'pub get'
  ///     pubspec.yaml
  void _setupPackages({
    required bool includeDependenciesWithExtensions,
    required bool includeBadExtension,
  }) {
    _setupPackage(
      createTestPackageFrom(
        includeBadExtension ? myAppPackageWithBadExtension : myAppPackage,
        includeDependenciesWithExtensions: includeDependenciesWithExtensions,
      ),
      isRuntimeRoot: true,
    );
    _setupPackage(
      createTestPackageFrom(
        otherRoot1Package,
        includeDependenciesWithExtensions: includeDependenciesWithExtensions,
      ),
    );
    _setupPackage(
      createTestPackageFrom(
        otherRoot2Package,
        includeDependenciesWithExtensions: includeDependenciesWithExtensions,
      ),
    );
  }

  /// extensions/
  ///   bad_extension/            # Only added when [includeBadExtension] is true.
  ///     extension/
  ///       devtools/
  ///         build/
  ///         config.yaml
  ///     pubspec.yaml
  ///   newer/
  ///     static_extension_1/
  ///       extension/
  ///         devtools/
  ///           build/
  ///           config.yaml
  ///   static_extension_1/
  ///     extension/
  ///       devtools/
  ///         build/
  ///         config.yaml
  ///   static_extension_2/
  ///     extension/
  ///       devtools/
  ///         build/
  ///         config.yaml
  void _setupExtensions({required bool includeBadExtension}) {
    _setupExtension(staticExtension1Package);
    _setupExtension(staticExtension2Package);

    // This extension is a duplicate of 'static_extension_1' with a newer
    // version (2.0.0 vs 1.0.0), and it lives in a different directory.
    _setupExtension(newerStaticExtension1Package);

    if (includeBadExtension) _setupExtension(badExtensionPackage);
  }

  void _setupPackage(TestPackage package, {bool isRuntimeRoot = false}) {
    final packagesDirectory = Directory(p.join(testDirectory.path, 'packages'))
      ..createSync(recursive: true);
    _packagesRootUri = Uri.file(packagesDirectory.uri.toFilePath());

    final projectRootDirectory =
        Directory(p.join(packagesDirectory.path, package.name))
          ..createSync(recursive: true);
    if (isRuntimeRoot) {
      final directoryPath =
          Uri.file(projectRootDirectory.uri.toFilePath()).toString();
      // Remove the trailing slash and set the value of [packagesRoot].
      _runtimeAppRoot = directoryPath.substring(0, directoryPath.length - 1);
    }

    File(p.join(projectRootDirectory.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync(package.pubspecContent, flush: true);
  }

  void _setupExtension(TestPackageWithExtension package) {
    final extensionDirectory = Directory(
      p.join(
        testDirectory.path,
        'extensions',
        package.relativePathFromExtensions,
      ),
    )..createSync(recursive: true);
    final extensionDir =
        Directory(p.join(extensionDirectory.path, 'extension', 'devtools'))
          ..createSync(recursive: true);
    Directory(p.join(extensionDir.path, 'build')).createSync(recursive: true);

    File(p.join(extensionDir.path, 'config.yaml'))
      ..createSync()
      ..writeAsStringSync(package.configYamlContent, flush: true);

    File(p.join(extensionDirectory.path, 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync(package.pubspecContent, flush: true);
  }
}

TestPackage createTestPackageFrom(
  TestPackage originalPackage, {
  required bool includeDependenciesWithExtensions,
}) {
  return TestPackage(
    name: originalPackage.name,
    dependencies:
        includeDependenciesWithExtensions ? originalPackage.dependencies : [],
  );
}

final myAppPackage = TestPackage(
  name: 'my_app',
  dependencies: [driftPackage, providerPackage, staticExtension1Package],
);
final myAppPackageWithBadExtension = TestPackage(
  name: myAppPackage.name,
  dependencies: [...myAppPackage.dependencies, badExtensionPackage],
);
final otherRoot1Package = TestPackage(
  name: 'other_root_1',
  dependencies: [staticExtension1Package, staticExtension2Package],
);
final otherRoot2Package = TestPackage(
  name: 'other_root_2',
  dependencies: [newerStaticExtension1Package],
);

final driftPackage = TestPackageWithExtension(
  name: 'drift',
  issueTracker: 'https://github.com/simolus3/drift/issues',
  version: '0.0.1',
  materialIconCodePoint: 62494,
  requiresConnection: true,
  isPubliclyHosted: true,
  packageVersion: '2.16.0',
);
final providerPackage = TestPackageWithExtension(
  name: 'provider',
  issueTracker: 'https://github.com/rrousselGit/provider/issues',
  version: '0.0.1',
  materialIconCodePoint: 57521,
  requiresConnection: true,
  isPubliclyHosted: true,
  packageVersion: '6.1.2',
);
final staticExtension1Package = TestPackageWithExtension(
  name: 'static_extension_1',
  issueTracker: 'https://www.google.com/',
  version: '1.0.0',
  materialIconCodePoint: 0xe50a,
  requiresConnection: false,
  isPubliclyHosted: false,
  packageVersion: null,
);
final staticExtension2Package = TestPackageWithExtension(
  name: 'static_extension_2',
  issueTracker: 'https://www.google.com/',
  version: '2.0.0',
  materialIconCodePoint: 0xe50a,
  requiresConnection: false,
  isPubliclyHosted: false,
  packageVersion: null,
);
final newerStaticExtension1Package = TestPackageWithExtension(
  name: 'static_extension_1',
  issueTracker: 'https://www.google.com/',
  version: '2.0.0',
  materialIconCodePoint: 0xe50a,
  requiresConnection: false,
  isPubliclyHosted: false,
  packageVersion: null,
  relativePathFromExtensions: p.join('newer', 'static_extension_1'),
);
final badExtensionPackage = TestPackageWithExtension(
  // Extension names must be only lowercase letters and underscores.
  name: 'BAD_EXTENSION',
  issueTracker: 'https://www.google.com/',
  version: '1.0.0',
  materialIconCodePoint: 0xe50a,
  requiresConnection: true,
  isPubliclyHosted: false,
  packageVersion: null,
);

class TestPackageWithExtension {
  TestPackageWithExtension({
    required this.name,
    required this.issueTracker,
    required this.version,
    required this.materialIconCodePoint,
    required this.requiresConnection,
    required this.isPubliclyHosted,
    required this.packageVersion,
    String? relativePathFromExtensions,
  })  : assert(isPubliclyHosted == (packageVersion != null)),
        relativePathFromExtensions =
            relativePathFromExtensions ?? name.toLowerCase();

  final String name;
  final String issueTracker;
  final String version;
  final Object? materialIconCodePoint;
  final bool requiresConnection;
  final bool isPubliclyHosted;
  final String? packageVersion;
  final String relativePathFromExtensions;

  String get configYamlContent => '''
name: $name
issueTracker: $issueTracker
version: $version
materialIconCodePoint: $materialIconCodePoint
${!requiresConnection ? 'requiresConnection: false' : ''}
''';

  String get pubspecContent => '''
name: ${name.toLowerCase()}
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
''';
}

class TestPackage {
  const TestPackage({required this.name, required this.dependencies});

  final String name;
  final List<TestPackageWithExtension> dependencies;

  String get pubspecContent => '''
name: $name
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:
${_dependenciesAsString()}
''';

  String _dependenciesAsString() {
    final sb = StringBuffer();
    for (final dep in dependencies) {
      sb.write('  ${dep.name.toLowerCase()}:');
      if (dep.isPubliclyHosted) {
        sb.writeln(' ${dep.packageVersion!}');
      } else {
        sb
          ..writeln() // Add a new line for the path dependency.
          ..writeln(
            '    path: ../../extensions/${dep.relativePathFromExtensions}',
          );
      }
    }
    return sb.toString();
  }
}
