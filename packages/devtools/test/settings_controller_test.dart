// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools/src/globals.dart';
import 'package:devtools/src/settings/settings_controller.dart';
import 'package:devtools/src/version.dart';
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

      FlutterVersion flutterVersion;
      List<Flag> flags;
      settingsController = SettingsController(
        onFlutterVersionChanged: (version) {
          flutterVersion = version;
        },
        onFlagListChanged: (flagList) {
          flags = flagList.flags;
        },
      );

      expect(flags, null);
      expect(flutterVersion, null);

      await settingsController.entering();

      // TODO(kenzie): remove the try catch block once Flutter stable supports
      // the flutterVersion service. Revisit this end of November 2019.
      try {
        final flutterVersionResponse = await serviceManager.getFlutterVersion();
        final expectedFlutterVersion =
            FlutterVersion.parse(flutterVersionResponse.json);
        expect(flutterVersion, equals(expectedFlutterVersion));
      } catch (e) {
        expect(flutterVersion, isNull);
        expect(
          e.toString(),
          equals('Exception: There are no registered methods for service'
              ' "flutterVersion"'),
        );
      }

      expect(flags, isNotNull);

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

      await env.tearDownEnvironment(force: true);
    });
  }, timeout: const Timeout.factor(8), tags: 'useFlutterSdk');
  // TODO: Add a test that uses DartVM instead of Flutter
}
