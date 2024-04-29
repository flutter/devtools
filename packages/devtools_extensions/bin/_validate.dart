// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_extensions_io.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Command that validates that a DevTools extension meets the requirements for
/// loading successfully in DevTools.
///
/// Example usage:
///
/// dart run devtools_extensions validate --package=../your_pub_package
class ValidateExtensionCommand extends Command {
  ValidateExtensionCommand() {
    argParser.addOption(
      _packageKey,
      help: 'The location of the package that this extension is published with',
      abbr: 'p',
      valueHelp: 'path/to/foo/packages/foo',
      mandatory: true,
    );
  }

  static const _packageKey = 'package';

  @override
  String get name => 'validate';

  @override
  String get description =>
      'Command that validates that a DevTools extension meets the '
      'requirements for loading successfully in DevTools.';

  static const docUrl = 'https://docs.flutter.dev/tools/devtools/extensions';

  @override
  Future<void> run() async {
    final packagePath = argResults?[_packageKey]! as String;
    try {
      // TODO(kenz): try to use the the existing pub validator for this check. See
      // https://github.com/dart-lang/pub/blob/master/lib/src/validator/devtools_extension.dart.
      _validateDirectoryContents(packagePath);

      // Try to parse the config.yaml file. This will throw an exception if there
      // are parsing errors.
      DevToolsExtensionConfig.parse(
        {
          ..._configAsMap(packagePath),
          // These are generated on the DevTools server, so pass in stubbed
          // values for the sake of validation.
          DevToolsExtensionConfig.extensionAssetsPathKey: '',
          DevToolsExtensionConfig.devtoolsOptionsUriKey: '',
          DevToolsExtensionConfig.isPubliclyHostedKey: 'false',
          DevToolsExtensionConfig.detectedFromStaticContextKey: 'false',
        },
      );

      // If there are no exceptions at this point, the extension has successfully
      // been validated.
      stdout.writeln('Extension validation successful');
    } on StateError catch (e) {
      _logError(e.message);
    } on FileSystemException catch (e) {
      _logError(e.message);
    } catch (e) {
      _logError(e.toString());
    }
  }
}

void _validateDirectoryContents(String packagePath) {
  final packageDirectory = Directory(packagePath);
  if (!packageDirectory.existsSync()) {
    throw FileSystemException('${packageDirectory.path} directory not found');
  }

  final devtoolsExtensionDir = Directory(
    path.join(packageDirectory.path, 'extension', 'devtools'),
  );
  if (!devtoolsExtensionDir.existsSync()) {
    throw const FileSystemException(
      '''
An extension/devtools directory is required, but none was found.
See ${ValidateExtensionCommand.docUrl}.
''',
    );
  }

  final buildDir = Directory(path.join(devtoolsExtensionDir.path, 'build'));
  if (!buildDir.existsSync()) {
    throw const FileSystemException(
      '''
An extension/devtools/build directory is required, but none was found.
See ${ValidateExtensionCommand.docUrl}.
''',
    );
  }
  if (buildDir.listSync().isEmpty) {
    throw const FileSystemException(
      '''
A non-empty extension/devtools/build directory is required, but the directory is empty.
See ${ValidateExtensionCommand.docUrl}.
''',
    );
  }

  final configFile = _lookupConfigFile(packagePath);
  if (!configFile.existsSync()) {
    throw const FileSystemException(
      '''
An extension/devtools/config.yaml file is required, but none was found.
See ${ValidateExtensionCommand.docUrl}.
''',
    );
  }
}

Map<String, Object?> _configAsMap(String packagePath) {
  final configFile = _lookupConfigFile(packagePath);
  // At this point, we know the config.yaml file exists.
  assert(configFile.existsSync());
  final yamlMap = loadYaml(configFile.readAsStringSync()) as YamlMap;
  return yamlMap.toDartMap();
}

File _lookupConfigFile(String packagePath) {
  return File(
    path.join(packagePath, 'extension', 'devtools', 'config.yaml'),
  );
}

void _logError(String error) {
  stderr.writeln('Validation error: $error');
}
