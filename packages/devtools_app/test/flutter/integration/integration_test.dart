// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:devtools_app/src/flutter/app.dart';
import 'package:devtools_app/src/flutter/connect_screen.dart';
import 'package:devtools_app/src/framework/framework_core.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_screen.dart';
import 'package:devtools_app/src/inspector/flutter_widget.dart';
import 'package:devtools_app/src/ui/fake_flutter/fake_flutter.dart';
import 'package:devtools_testing/support/file_utils.dart';
import 'package:devtools_testing/support/flutter_test_driver.dart';
import 'package:devtools_testing/support/flutter_test_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  if (Platform.isLinux)
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  // This integration test can only be run with LiveWidgetsFlutterBinding.
  // This test cannot be run as a flutter driver test instead because of
  // https://github.com/flutter/flutter/issues/49843 (Chrome),
  // https://github.com/flutter/flutter/issues/49841 (Mac),
  // (Nor on Linux either).

  TestWidgetsFlutterBinding.ensureInitialized({'FLUTTER_TEST': 'false'});
  HttpOverrides.global = null;
  assert(
      WidgetsBinding.instance is LiveTestWidgetsFlutterBinding,
      'The integration tests must run with a LiveWidgetsBinding.\n'
      'These tests make real async calls that cannot be wrapped in a\n'
      'FakeAsync zone.\n'
      'The current binding is ${WidgetsBinding.instance}.\n'
      '\n'
      'You can likely fix this by running the test on platform vm with\n'
      '`flutter run` instead of `flutter test`\n');
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );
  compensateForFlutterTestDirectoryBug();
  Catalog.setCatalog(Catalog.decode(await widgetsJson()));

  group('Whole app', () {
    testWidgets('connects to a dart app', (tester) async {
      FrameworkCore.init('');
      final app = DefaultAssetBundle(
        bundle: _DiskAssetBundle(),
        child: DevToolsApp(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byType(ConnectScreenBody), findsOneWidget);
      await expectLater(
        find.byWidget(app),
        matchesGoldenFile('ConnectScreen.png'),
      );

      await env.setupEnvironment();
      await tester.enterText(
        find.byType(TextField),
        env.flutter.vmServiceUri.toString(),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.byType(RaisedButton));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await expectLater(
        find.byWidget(app),
        matchesGoldenFile('InspectorScreen.png'),
      );
      expect(find.byType(InspectorScreenBody), findsOneWidget);

      await env.tearDownEnvironment();
      // Tests fail if target platform is overridden.
      debugDefaultTargetPlatformOverride = null;
    });

    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });
  });
}

class _DiskAssetBundle extends CachingAssetBundle {
  static const _assetManifestDotJson = 'AssetManifest.json';
  @override
  Future<ByteData> load(String key) async {
    if (key == _assetManifestDotJson) {
      final files = [
        ...Directory('web/').listSync(recursive: true),
        ...Directory('assets/').listSync(recursive: true),
        ...Directory('fonts/').listSync(recursive: true),
      ].where((fse) => fse is File);

      final manifest = <String, List<String>>{
        for (var file in files) file.path: [file.path]
      };

      return ByteData.view(
        Uint8List.fromList(jsonEncode(manifest).codeUnits).buffer,
      );
    }
    return ByteData.view(
      (await File('${Directory.current.path}/$key').readAsBytes()).buffer,
    );
  }
}
