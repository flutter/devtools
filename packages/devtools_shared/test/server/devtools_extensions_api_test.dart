// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_shared/src/extensions/extension_manager.dart';
import 'package:devtools_shared/src/server/server_api.dart';
import 'package:dtd/dtd.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../fakes.dart';
import '../helpers/extension_test_manager.dart';
import '../helpers/helpers.dart';

void main() {
  final extensionTestManager = ExtensionTestManager();

  late ExtensionsManager extensionsManager;
  TestDtdConnectionInfo? dtd;
  DartToolingDaemon? testDtdConnection;

  setUp(() async {
    extensionsManager = ExtensionsManager();
    dtd = await startDtd();
    expect(dtd!.info, isNotNull, reason: 'Error starting DTD for test');
    testDtdConnection = await DartToolingDaemon.connect(dtd!.info!.localUri);
  });

  tearDown(() async {
    await testDtdConnection?.close();
    dtd?.process?.kill();
    await dtd?.process?.exitCode;
    dtd = null;

    await extensionTestManager.reset();
  });

  Future<void> initializeTestDirectory({
    bool includeDependenciesWithExtensions = true,
    bool includeBadExtension = false,
    bool includeSpoofedExtension = false,
  }) async {
    await extensionTestManager.setupTestDirectoryStructure(
      includeDependenciesWithExtensions: includeDependenciesWithExtensions,
      includeBadExtension: includeBadExtension,
      includeSpoofedExtension: includeSpoofedExtension,
    );
    await testDtdConnection!.setIDEWorkspaceRoots(dtd!.info!.secret!, [
      extensionTestManager.packagesRootUri,
    ]);
  }

  Future<Response> serveExtensions(
    ExtensionsManager manager, {
    bool includeRuntimeRoot = true,
  }) async {
    final request = Request(
      'post',
      Uri(
        scheme: 'https',
        host: 'localhost',
        path: ExtensionsApi.apiServeAvailableExtensions,
        queryParameters: {
          ExtensionsApi.packageRootUriPropertyName: includeRuntimeRoot
              ? extensionTestManager.runtimeAppRoot
              : null,
        },
      ),
    );
    return await ServerApi.handle(
      request,
      extensionsManager: manager,
      deeplinkManager: FakeDeeplinkManager(),
      dtd: dtd!.info,
    );
  }

  group(ExtensionsApi.apiServeAvailableExtensions, () {
    test('succeeds for valid extensions', () async {
      await initializeTestDirectory();
      final response = await serveExtensions(extensionsManager);
      expect(response.statusCode, HttpStatus.ok);
      _verifyAllExtensions(extensionsManager);
    });

    test('succeeds for valid extensions static only', () async {
      await initializeTestDirectory();
      final response = await serveExtensions(
        extensionsManager,
        includeRuntimeRoot: false,
      );
      expect(response.statusCode, HttpStatus.ok);
      _verifyAllExtensions(extensionsManager, includeRuntime: false);
    });

    test('succeeds with mix of valid and invalid extensions', () async {
      await initializeTestDirectory(includeBadExtension: true);
      final response = await serveExtensions(extensionsManager);
      expect(response.statusCode, HttpStatus.ok);
      _verifyAllExtensions(extensionsManager);

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final warning =
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName];
      expect(
        warning,
        contains('Encountered errors while parsing extension config.yaml'),
      );
    });

    test(
      'spoofed extension is isolated by packageName and cannot overwrite legitimate extension',
      () async {
        await initializeTestDirectory(includeSpoofedExtension: true);
        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.ok);

        // Verify that the legitimate provider extension is present.
        final providerExtension = extensionsManager.devtoolsExtensions
            .firstWhereOrNull((e) => e.packageName == 'provider');
        expect(providerExtension, isNotNull);
        expect(providerExtension!.name, 'provider');
        expect(providerExtension.version, providerPackage.version);

        // Verify that the spoofed extension from bad_pkg is isolated under packageName 'bad_pkg'.
        final spoofedExtension = extensionsManager.devtoolsExtensions
            .firstWhereOrNull((e) => e.packageName == 'bad_pkg');
        expect(spoofedExtension, isNotNull);
        expect(spoofedExtension!.name, 'provider');
        expect(spoofedExtension.version, '999.0.0');
        expect(spoofedExtension.identifier, 'bad_pkg_provider_999.0.0');

        // Verify lookupLocationFor returns the respective paths without collision.
        expect(
          extensionsManager.lookupLocationFor(providerExtension.identifier),
          providerExtension.extensionAssetsPath,
        );
        expect(
          extensionsManager.lookupLocationFor(spoofedExtension.identifier),
          spoofedExtension.extensionAssetsPath,
        );
      },
    );

    test('succeeds for valid extensions when an exception is thrown', () async {
      await initializeTestDirectory();
      extensionsManager = _TestExtensionsManager();
      final response = await serveExtensions(extensionsManager);
      expect(response.statusCode, HttpStatus.ok);
      _verifyAllExtensions(extensionsManager);

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final warning =
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName];
      expect(warning, contains('Fake exception for test'));
    });

    test(
      'fails when an exception is thrown and there are no valid extensions',
      () async {
        await initializeTestDirectory(includeDependenciesWithExtensions: false);
        extensionsManager = _TestExtensionsManager();
        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.internalServerError);
        expect(extensionsManager.devtoolsExtensions, isEmpty);

        final parsedResponse =
            json.decode(await response.readAsString()) as Map;
        final error = parsedResponse['error'];
        expect(error, contains('Fake exception for test'));
      },
    );

    test(
      'rejects packageRootUri with non-empty host (Windows UNC path)',
      () async {
        await initializeTestDirectory();
        const uncUri = 'file://remotehost/share/app';
        final request = Request(
          'post',
          Uri(
            scheme: 'https',
            host: 'localhost',
            path: ExtensionsApi.apiServeAvailableExtensions,
            queryParameters: {ExtensionsApi.packageRootUriPropertyName: uncUri},
          ),
        );
        final response = await ServerApi.handle(
          request,
          extensionsManager: extensionsManager,
          deeplinkManager: FakeDeeplinkManager(),
          dtd: dtd!.info,
        );
        expect(response.statusCode, HttpStatus.badRequest);
        expect(extensionsManager.devtoolsExtensions, isEmpty);

        await expectLater(
          extensionsManager.serveAvailableExtensions(uncUri, <String>[], null),
          throwsArgumentError,
        );
      },
    );

    test('rejects extension config.yaml with absolute buildLocation', () async {
      await initializeTestDirectory();
      final posixAbsConfigFile = File(
        p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          staticExtension2Package.relativePathFromExtensions,
          'extension',
          'devtools',
          'config.yaml',
        ),
      );
      posixAbsConfigFile.writeAsStringSync(
        '${staticExtension2Package.configYamlContent}\nbuildLocation: /tmp\n',
        flush: true,
      );

      final windowsAbsConfigFile = File(
        p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          newerStaticExtension1Package.relativePathFromExtensions,
          'extension',
          'devtools',
          'config.yaml',
        ),
      );
      windowsAbsConfigFile.writeAsStringSync(
        '${newerStaticExtension1Package.configYamlContent}\n'
        r'buildLocation: C:\'
        '\n',
        flush: true,
      );

      final response = await serveExtensions(extensionsManager);
      expect(response.statusCode, HttpStatus.ok);
      expect(
        extensionsManager.devtoolsExtensions.where(
          (e) => e.packageName == staticExtension2Package.packageName,
        ),
        isEmpty,
      );
      expect(
        extensionsManager.devtoolsExtensions.where(
          (e) =>
              e.packageName == newerStaticExtension1Package.packageName &&
              e.version == newerStaticExtension1Package.version,
        ),
        isEmpty,
      );

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final warning =
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName]
              as String;
      expect(
        warning,
        contains('Encountered errors while parsing extension config.yaml'),
      );
      expect(warning, contains('must be a relative path'));
    });

    test(
      'rejects extension with symlink pointing outside build directory',
      () async {
        await initializeTestDirectory();
        final secretFile = File(
          p.join(extensionTestManager.testDirectory.path, 'secret.txt'),
        )..writeAsStringSync('top secret', flush: true);

        final extensionBuildDir = Directory(
          p.join(
            extensionTestManager.testDirectory.path,
            'extensions',
            staticExtension2Package.relativePathFromExtensions,
            'extension',
            'devtools',
            'build',
          ),
        );
        Link(
          p.join(extensionBuildDir.path, 'secret_link.txt'),
        ).createSync(secretFile.path);

        final outsideBuildDir = Directory(
          p.join(extensionTestManager.testDirectory.path, 'outside_build'),
        )..createSync(recursive: true);
        final newerBuildDir = Directory(
          p.join(
            extensionTestManager.testDirectory.path,
            'extensions',
            newerStaticExtension1Package.relativePathFromExtensions,
            'extension',
            'devtools',
            'build',
          ),
        );
        newerBuildDir.deleteSync(recursive: true);
        Link(newerBuildDir.path).createSync(outsideBuildDir.path);

        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.ok);
        expect(
          extensionsManager.devtoolsExtensions.where(
            (e) => e.packageName == staticExtension2Package.packageName,
          ),
          isEmpty,
        );
        expect(
          extensionsManager.devtoolsExtensions.where(
            (e) =>
                e.packageName == newerStaticExtension1Package.packageName &&
                e.version == newerStaticExtension1Package.version,
          ),
          isEmpty,
        );

        final parsedResponse =
            json.decode(await response.readAsString()) as Map;
        final warning =
            parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName]
                as String;
        expect(
          warning,
          contains('Encountered errors while parsing extension config.yaml'),
        );
        expect(
          warning,
          contains('contains a symlink pointing outside the build directory'),
        );
        expect(warning, contains('resolves outside package root'));
      },
    );

    test('rejects extension with broken or outside directory symlink inside '
        'build directory', () async {
      await initializeTestDirectory();
      final extensionBuildDir = Directory(
        p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          staticExtension2Package.relativePathFromExtensions,
          'extension',
          'devtools',
          'build',
        ),
      );
      Link(
        p.join(extensionBuildDir.path, 'broken_link.txt'),
      ).createSync(p.join(extensionBuildDir.path, 'does_not_exist.txt'));

      final outsideDir = Directory(
        p.join(extensionTestManager.testDirectory.path, 'outside_dir'),
      )..createSync(recursive: true);
      final newerBuildDir = Directory(
        p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          newerStaticExtension1Package.relativePathFromExtensions,
          'extension',
          'devtools',
          'build',
        ),
      );
      Link(
        p.join(newerBuildDir.path, 'outside_dir_link'),
      ).createSync(outsideDir.path);

      final response = await serveExtensions(extensionsManager);
      expect(response.statusCode, HttpStatus.ok);
      expect(
        extensionsManager.devtoolsExtensions.where(
          (e) => e.packageName == staticExtension2Package.packageName,
        ),
        isEmpty,
      );
      expect(
        extensionsManager.devtoolsExtensions.where(
          (e) =>
              e.packageName == newerStaticExtension1Package.packageName &&
              e.version == newerStaticExtension1Package.version,
        ),
        isEmpty,
      );

      final parsedResponse = json.decode(await response.readAsString()) as Map;
      final warning =
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName]
              as String;
      expect(
        warning,
        contains('contains a symlink pointing outside the build directory'),
      );
    });

    test(
      'allows extension with symlinks pointing within build directory',
      () async {
        await initializeTestDirectory();
        final extensionBuildDir = Directory(
          p.join(
            extensionTestManager.testDirectory.path,
            'extensions',
            staticExtension2Package.relativePathFromExtensions,
            'extension',
            'devtools',
            'build',
          ),
        );
        final indexFile = File(p.join(extensionBuildDir.path, 'index.html'))
          ..writeAsStringSync('<html></html>', flush: true);
        final assetsDir = Directory(p.join(extensionBuildDir.path, 'assets'))
          ..createSync(recursive: true);
        File(
          p.join(assetsDir.path, 'data.json'),
        ).writeAsStringSync('{}', flush: true);

        Link(
          p.join(extensionBuildDir.path, 'alias.html'),
        ).createSync(indexFile.path);
        Link(
          p.join(extensionBuildDir.path, 'assets_alias'),
        ).createSync(assetsDir.path);
        Link(
          p.join(extensionBuildDir.path, 'self_link'),
        ).createSync(extensionBuildDir.path);

        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.ok);
        final parsedResponse =
            json.decode(await response.readAsString()) as Map;
        expect(
          parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName],
          isNull,
        );
        _verifyAllExtensions(extensionsManager);
      },
    );

    test(
      'rejects extension with non-existent or non-directory buildLocation',
      () async {
        await initializeTestDirectory();
        final missingBuildDir = Directory(
          p.join(
            extensionTestManager.testDirectory.path,
            'extensions',
            staticExtension2Package.relativePathFromExtensions,
            'extension',
            'devtools',
            'build',
          ),
        );
        missingBuildDir.deleteSync(recursive: true);

        final regularFileBuildPath = p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          newerStaticExtension1Package.relativePathFromExtensions,
          'extension',
          'devtools',
          'build',
        );
        Directory(regularFileBuildPath).deleteSync(recursive: true);
        File(
          regularFileBuildPath,
        ).writeAsStringSync('not a directory', flush: true);

        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.ok);
        expect(
          extensionsManager.devtoolsExtensions.where(
            (e) => e.packageName == staticExtension2Package.packageName,
          ),
          isEmpty,
        );
        expect(
          extensionsManager.devtoolsExtensions.where(
            (e) =>
                e.packageName == newerStaticExtension1Package.packageName &&
                e.version == newerStaticExtension1Package.version,
          ),
          isEmpty,
        );

        final parsedResponse =
            json.decode(await response.readAsString()) as Map;
        final warning =
            parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName]
                as String;
        expect(
          warning,
          contains('Encountered errors while parsing extension config.yaml'),
        );
        expect(
          warning,
          contains(
            'Ignoring extension from package '
            '"${staticExtension2Package.packageName}": invalid buildLocation '
            '"build" does not exist or is not a directory.',
          ),
        );
        expect(
          warning,
          contains(
            'Ignoring extension from package '
            '"${newerStaticExtension1Package.packageName}": invalid '
            'buildLocation "build" does not exist or is not a directory.',
          ),
        );
      },
    );

    test(
      'rejects extension with broken or non-directory symlink buildLocation',
      () async {
        await initializeTestDirectory();
        final brokenSymlinkBuildPath = p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          staticExtension2Package.relativePathFromExtensions,
          'extension',
          'devtools',
          'build',
        );
        Directory(brokenSymlinkBuildPath).deleteSync(recursive: true);
        Link(brokenSymlinkBuildPath).createSync(
          p.join(extensionTestManager.testDirectory.path, 'does_not_exist'),
        );

        final newerDevToolsDir = p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          newerStaticExtension1Package.relativePathFromExtensions,
          'extension',
          'devtools',
        );
        final fileSymlinkBuildPath = p.join(newerDevToolsDir, 'build');
        Directory(fileSymlinkBuildPath).deleteSync(recursive: true);
        Link(
          fileSymlinkBuildPath,
        ).createSync(p.join(newerDevToolsDir, 'config.yaml'));

        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.ok);
        expect(
          extensionsManager.devtoolsExtensions.where(
            (e) => e.packageName == staticExtension2Package.packageName,
          ),
          isEmpty,
        );
        expect(
          extensionsManager.devtoolsExtensions.where(
            (e) =>
                e.packageName == newerStaticExtension1Package.packageName &&
                e.version == newerStaticExtension1Package.version,
          ),
          isEmpty,
        );

        final parsedResponse =
            json.decode(await response.readAsString()) as Map;
        final warning =
            parsedResponse[ExtensionsApi.extensionsResultWarningPropertyName]
                as String;
        expect(
          warning,
          contains('Encountered errors while parsing extension config.yaml'),
        );
        expect(
          warning,
          contains(
            'Ignoring extension from package '
            '"${staticExtension2Package.packageName}": invalid buildLocation '
            '"build" is a broken or non-directory symlink.',
          ),
        );
        expect(
          warning,
          contains(
            'Ignoring extension from package '
            '"${newerStaticExtension1Package.packageName}": invalid '
            'buildLocation "build" is a broken or non-directory symlink.',
          ),
        );
      },
    );

    test(
      'stores canonical resolvedLocation and prevents post-discovery symlink '
      'manipulation',
      () async {
        await initializeTestDirectory();
        final packageRoot = p.join(
          extensionTestManager.testDirectory.path,
          'extensions',
          staticExtension2Package.relativePathFromExtensions,
        );
        final customBuildDir = Directory(p.join(packageRoot, 'custom_build'))
          ..createSync(recursive: true);
        File(
          p.join(customBuildDir.path, 'index.html'),
        ).writeAsStringSync('<html></html>', flush: true);

        final symlinkBuildPath = p.join(
          packageRoot,
          'extension',
          'devtools',
          'build',
        );
        Directory(symlinkBuildPath).deleteSync(recursive: true);
        Link(symlinkBuildPath).createSync(customBuildDir.path);

        final response = await serveExtensions(extensionsManager);
        expect(response.statusCode, HttpStatus.ok);

        final registered = extensionsManager.devtoolsExtensions
            .firstWhereOrNull(
              (e) => e.packageName == staticExtension2Package.packageName,
            );
        expect(registered, isNotNull);

        final canonicalBuildPath = p.normalize(
          customBuildDir.resolveSymbolicLinksSync(),
        );
        expect(registered!.extensionAssetsPath, canonicalBuildPath);
        expect(
          extensionsManager.lookupLocationFor(registered.identifier),
          canonicalBuildPath,
        );

        // Mutating the symlink after discovery should not affect the stored or
        // looked-up canonical assets path.
        final outsideDir = Directory(
          p.join(extensionTestManager.testDirectory.path, 'outside_build'),
        )..createSync(recursive: true);
        Link(symlinkBuildPath).deleteSync();
        Link(symlinkBuildPath).createSync(outsideDir.path);

        expect(registered.extensionAssetsPath, canonicalBuildPath);
        expect(
          extensionsManager.lookupLocationFor(registered.identifier),
          canonicalBuildPath,
        );
      },
    );
  });

  group(ExtensionsApi.apiExtensionEnabledState, () {
    late File optionsFile;
    late String optionsFileUriString;

    setUp(() async {
      await initializeTestDirectory();
      // Recompute per test: each test gets a fresh temp directory, so this
      // must not be cached across tests (otherwise it would point at a
      // previous test's directory).
      optionsFileUriString = p.posix.join(
        extensionTestManager.runtimeAppRoot,
        devtoolsOptionsFileName,
      );
      optionsFile = File.fromUri(Uri.parse(optionsFileUriString));
    });

    Future<Response> sendEnabledStateRequest({
      required String extensionName,
      bool? enable,
      String? optionsUriOverride,
    }) async {
      final request = Request(
        'post',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: ExtensionsApi.apiExtensionEnabledState,
          queryParameters: {
            ExtensionsApi.devtoolsOptionsUriPropertyName:
                optionsUriOverride ?? optionsFileUriString,
            ExtensionsApi.extensionNamePropertyName: extensionName,
            if (enable != null)
              ExtensionsApi.enabledStatePropertyName: enable.toString(),
          },
        ),
      );
      return await ServerApi.handle(
        request,
        extensionsManager: extensionsManager,
        deeplinkManager: FakeDeeplinkManager(),
      );
    }

    test('rejects a devtoolsOptionsUri that is not a devtools_options.yaml '
        'file', () async {
      await serveExtensions(extensionsManager);
      const invalidUris = [
        // Wrong file name.
        'file:///tmp/evil.txt',
        'file:///tmp/devtools_options.yaml.bak',
        // Non-file scheme.
        'https://evil.example.com/devtools_options.yaml',
        // UNC path / non-empty host.
        'file://remotehost/share/devtools_options.yaml',
      ];
      for (final invalidUri in invalidUris) {
        final response = await sendEnabledStateRequest(
          extensionName: 'drift',
          optionsUriOverride: invalidUri,
        );
        expect(
          response.statusCode,
          HttpStatus.badRequest,
          reason: 'expected $invalidUri to be rejected',
        );
      }
    });

    test('accepts a valid devtools_options.yaml file: URI', () async {
      await serveExtensions(extensionsManager);
      final response = await sendEnabledStateRequest(extensionName: 'drift');
      expect(response.statusCode, HttpStatus.ok);
    });

    test('options file does not exist until first acesss', () async {
      await serveExtensions(extensionsManager);
      expect(optionsFile.existsSync(), isFalse);
    });

    test('can get and set enabled states', () async {
      await serveExtensions(extensionsManager);
      var response = await sendEnabledStateRequest(extensionName: 'drift');
      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await response.readAsString()),
        ExtensionEnabledState.none.name,
      );

      response = await sendEnabledStateRequest(extensionName: 'provider');
      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await response.readAsString()),
        ExtensionEnabledState.none.name,
      );

      // TODO(kenz): why is existsSync() returning false when I can verify the file
      // contents on the file system at [optionsFileUriString]?
      //       expect(optionsFile.existsSync(), isTrue);
      //       expect(
      //         optionsFile.readAsStringSync(),
      //         '''
      // description: This file stores settings for Dart & Flutter DevTools.
      // documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
      // extensions:''',
      //       );

      response = await sendEnabledStateRequest(
        extensionName: 'drift',
        enable: true,
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await response.readAsString()),
        ExtensionEnabledState.enabled.name,
      );

      response = await sendEnabledStateRequest(
        extensionName: 'provider',
        enable: false,
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(
        jsonDecode(await response.readAsString()),
        ExtensionEnabledState.disabled.name,
      );

      //       expect(optionsFile.existsSync(), isTrue);
      //       expect(
      //         optionsFile.readAsStringSync(),
      //         '''
      // description: This file stores settings for Dart & Flutter DevTools.
      // documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
      // extensions:
      //   - drift: true
      //   - provider: false''',
      //       );
    });
  });
}

class _TestExtensionsManager extends ExtensionsManager {
  @override
  Future<void> serveAvailableExtensions(
    String? rootFileUriString,
    List<String> logs,
    DtdInfo? dtd,
  ) async {
    await super.serveAvailableExtensions(rootFileUriString, logs, dtd);
    throw Exception('Fake exception for test');
  }
}

void _verifyAllExtensions(
  ExtensionsManager extensionsManager, {
  bool includeRuntime = true,
}) {
  if (includeRuntime) {
    expect(extensionsManager.devtoolsExtensions.length, 11);
    final runtimeExtensions = extensionsManager.devtoolsExtensions
        .where((ext) => !ext.detectedFromStaticContext)
        .toList();
    _verifyExpectedRuntimeExtensions(runtimeExtensions);
  }

  final staticExtensions = extensionsManager.devtoolsExtensions
      .where((ext) => ext.detectedFromStaticContext)
      .toList();
  _verifyExpectedStaticExtensions(staticExtensions);
}

void _verifyExpectedRuntimeExtensions(
  List<DevToolsExtensionConfig> extensions,
) {
  expect(extensions.length, 3);
  extensions.sort();
  _verifyExtension(
    extensions[0],
    extensionPackage: driftPackage,
    detectedFromPath: 'my_app',
    fromStaticContext: false,
  );
  _verifyExtension(
    extensions[1],
    extensionPackage: providerPackage,
    detectedFromPath: 'my_app',
    fromStaticContext: false,
  );
  _verifyExtension(
    extensions[2],
    extensionPackage: staticExtension1Package,
    detectedFromPath: 'my_app',
    fromStaticContext: false,
  );
}

void _verifyExpectedStaticExtensions(List<DevToolsExtensionConfig> extensions) {
  expect(extensions.length, 8);
  extensions.sort();
  _verifyExtension(
    extensions[0],
    extensionPackage: driftPackage,
    detectedFromPath: 'my_app',
    fromStaticContext: true,
  );
  _verifyExtension(
    extensions[1],
    extensionPackage: providerPackage,
    detectedFromPath: 'my_app',
    fromStaticContext: true,
  );
  _verifyExtension(
    extensions[2],
    extensionPackage: newerStaticExtension1Package,
    detectedFromPath: 'other_root_2',
    fromStaticContext: true,
  );
  _verifyExtension(
    extensions[3],
    extensionPackage: staticExtension1Package,
    detectedFromPath: 'my_app',
    fromStaticContext: true,
  );
  _verifyExtension(
    extensions[4],
    extensionPackage: staticExtension1Package,
    detectedFromPath: 'other_root_1',
    fromStaticContext: true,
  );
  // This extension gets added once by the workspace root pubspec.yaml, and once
  // by the workspace member pubspec.yaml.
  _verifyExtension(
    extensions[5],
    extensionPackage: staticExtension1Package,
    detectedFromPath: 'workspace_root',
    fromStaticContext: true,
  );
  _verifyExtension(
    extensions[6],
    extensionPackage: staticExtension1Package,
    detectedFromPath: 'workspace_root',
    fromStaticContext: true,
  );
  _verifyExtension(
    extensions[7],
    extensionPackage: staticExtension2Package,
    detectedFromPath: 'other_root_1',
    fromStaticContext: true,
  );
}

void _verifyExtension(
  DevToolsExtensionConfig ext, {
  required TestPackageWithExtension extensionPackage,
  required String detectedFromPath,
  required bool fromStaticContext,
}) {
  expect(ext.name, extensionPackage.name);
  expect(ext.packageName, extensionPackage.packageName);
  expect(ext.issueTrackerLink, extensionPackage.issueTracker);
  expect(ext.version, extensionPackage.version);
  expect(ext.materialIconCodePoint, extensionPackage.materialIconCodePoint);
  expect(ext.requiresConnection, extensionPackage.requiresConnection);
  expect(ext.isPubliclyHosted, extensionPackage.isPubliclyHosted);
  if (extensionPackage.isPubliclyHosted) {
    expect(
      ext.extensionAssetsPath,
      endsWith(
        p.join(
          Platform.isWindows ? r'Pub\Cache' : '.pub-cache',
          'hosted',
          'pub.dev',
          '${extensionPackage.name}-${extensionPackage.packageVersion}',
          'extension',
          'devtools',
          'build',
        ),
      ),
    );
  } else {
    expect(
      ext.extensionAssetsPath,
      contains(
        p.join(
          'extensions',
          extensionPackage.relativePathFromExtensions,
          'extension',
          'devtools',
          'build',
        ),
      ),
    );
  }
  expect(
    ext.extensionAssetsPath,
    p.normalize(Directory(ext.extensionAssetsPath).resolveSymbolicLinksSync()),
  );
  expect(
    ext.devtoolsOptionsUri,
    endsWith(
      p.posix.join('packages', detectedFromPath, devtoolsOptionsFileName),
    ),
  );
  expect(ext.detectedFromStaticContext, fromStaticContext);
}
