// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_extensions_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('$DevToolsOptions', () {
    late DevToolsOptions options;
    late Directory tmpDir;
    late Uri optionsUri;

    setUp(() {
      options = DevToolsOptions();
      tmpDir = Directory.current.createTempSync();
      optionsUri = Uri.file(p.join(tmpDir.path, devtoolsOptionsFileName));
    });

    tearDown(() {
      options = DevToolsOptions();
      tmpDir.deleteSync(recursive: true);
    });

    File optionsFileFromTmp() {
      final tmpFiles = tmpDir.listSync();
      expect(tmpFiles, isNotEmpty);
      final optionsFile = File.fromUri(optionsUri);
      expect(optionsFile.existsSync(), isTrue);
      return optionsFile;
    }

    test('extensionEnabledState creates options file when none exists', () {
      expect(tmpDir.listSync(), isEmpty);
      options.lookupExtensionEnabledState(
        devtoolsOptionsUri: optionsUri,
        extensionName: 'foo',
      );
      final file = optionsFileFromTmp();
      expect(
        file.readAsStringSync(),
        '''
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
''',
      );
    });

    test('can write to options file', () {
      options.setExtensionEnabledState(
        devtoolsOptionsUri: optionsUri,
        extensionName: 'foo',
        enable: true,
      );
      final file = optionsFileFromTmp();
      expect(
        file.readAsStringSync(),
        '''
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - foo: true''',
      );
    });

    test('can read from options file', () {
      options.setExtensionEnabledState(
        devtoolsOptionsUri: optionsUri,
        extensionName: 'foo',
        enable: true,
      );
      options.setExtensionEnabledState(
        devtoolsOptionsUri: optionsUri,
        extensionName: 'bar',
        enable: false,
      );
      final file = optionsFileFromTmp();
      expect(
        file.readAsStringSync(),
        '''
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - foo: true
  - bar: false''',
      );

      expect(
        options.lookupExtensionEnabledState(
          devtoolsOptionsUri: optionsUri,
          extensionName: 'foo',
        ),
        ExtensionEnabledState.enabled,
      );
      expect(
        options.lookupExtensionEnabledState(
          devtoolsOptionsUri: optionsUri,
          extensionName: 'bar',
        ),
        ExtensionEnabledState.disabled,
      );
      expect(
        options.lookupExtensionEnabledState(
          devtoolsOptionsUri: optionsUri,
          extensionName: 'baz',
        ),
        ExtensionEnabledState.none,
      );
    });
  });
}
