// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools/src/globals.dart';
import 'package:devtools/src/settings/settings_controller.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/flutter_test_driver.dart';
import 'support/flutter_test_environment.dart';

void main() async {
  SettingsController settingsController;
  final env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );
  group('settings controller test', () {
    test('entering', () async {
      await env.setupEnvironment();

      String sdkVersion;
      List<Flag> flags;
      settingsController =
          SettingsController(onSdkVersionChange: (isAnyFlutterApp) {
        sdkVersion = isAnyFlutterApp;
      }, onFlagListChange: (flagList) {
        flags = flagList.flags;
      });
      expect(sdkVersion, null);
      expect(flags, null);

      await settingsController.entering();
      expect(sdkVersion, 'Dart SDK Version: ${serviceManager.sdkVersion}');

      final flagList = await env.service.getFlagList();
      expect(flags.length, flagList.flags.length);
      final expectedFlags = [
        Flag.parse({
          'name': 'causal_async_stacks',
          'comment': 'Improved async stacks',
          'modified': true,
          'valueAsString': 'true'
        }),
        Flag.parse({
          'name': 'async_debugger',
          'comment': 'Debugger support async functions.',
          'modified': false,
          'valueAsString': 'true'
        }),
      ];
      for (var i = 0; i < flags.length; i++) {
        expect(flags[i].toString(), flagList.flags[i].toString());
        if (expectedFlags.isNotEmpty &&
            expectedFlags.last.toString() == flags[i].toString()) {
          expectedFlags.removeLast();
        }
      }
      expect(expectedFlags.length, 0);
    });
  }, tags: 'useFlutterSdk');
  // TODO: Add a test that uses DartVM instead of Flutter
}
