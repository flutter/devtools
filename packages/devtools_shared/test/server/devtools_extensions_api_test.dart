// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';

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
  }) async {
    await extensionTestManager.setupTestDirectoryStructure(
      includeDependenciesWithExtensions: includeDependenciesWithExtensions,
      includeBadExtension: includeBadExtension,
    );
    await testDtdConnection!.setIDEWorkspaceRoots(
      dtd!.info!.secret!,
      [extensionTestManager.packagesRootUri],
    );
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
          ExtensionsApi.packageRootUriPropertyName:
              includeRuntimeRoot ? extensionTestManager.runtimeAppRoot : null,
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
        await initializeTestDirectory(
          includeDependenciesWithExtensions: false,
        );
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
  });

  group(ExtensionsApi.apiExtensionEnabledState, () {
    late File optionsFile;
    late final optionsFileUriString = p.posix.join(
      extensionTestManager.runtimeAppRoot,
      devtoolsOptionsFileName,
    );

    setUp(() async {
      await initializeTestDirectory();
      optionsFile = File.fromUri(Uri.parse(optionsFileUriString));
    });

    Future<Response> sendEnabledStateRequest({
      required String extensionName,
      bool? enable,
    }) async {
      final request = Request(
        'post',
        Uri(
          scheme: 'https',
          host: 'localhost',
          path: ExtensionsApi.apiExtensionEnabledState,
          queryParameters: {
            ExtensionsApi.devtoolsOptionsUriPropertyName: optionsFileUriString,
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
    ext.devtoolsOptionsUri,
    endsWith(
      p.posix.join('packages', detectedFromPath, devtoolsOptionsFileName),
    ),
  );
  expect(ext.detectedFromStaticContext, fromStaticContext);
}
