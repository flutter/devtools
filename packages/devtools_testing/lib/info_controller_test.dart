// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/info/info_controller.dart';
import 'package:devtools_app/src/version.dart';
import 'package:devtools_app/src/vm_flags.dart' as vm_flags;
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/flutter_test_environment.dart';

Future<void> runInfoControllerTests(FlutterTestEnvironment env) async {
  InfoController infoController;
  group('info controller', () {
    test('entering', () async {
      await env.setupEnvironment();

      FlutterVersion flutterVersion;
      List<Flag> flags;
      infoController = InfoController(
        onFlutterVersionChanged: (version) {
          flutterVersion = version;
        },
        onFlagListChanged: (flagList) {
          flags = flagList.flags;
        },
      );

      expect(flags, null);
      expect(flutterVersion, null);

      await infoController.entering();

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
      final expectedFlags = <String>{};

      for (var flag in [
        Flag.parse({
          'name': vm_flags.causalAsyncStacks,
          'comment': 'Improved async stacks',
          'modified': true,
          'valueAsString': 'true'
        }),
        Flag.parse({
          'name': vm_flags.asyncDebugger,
          'comment': 'Debugger support async functions.',
          'modified': false,
          'valueAsString': 'true'
        }),
      ]) {
        expectedFlags.add(flag.toString());
      }

      for (var i = 0; i < flags.length; i++) {
        expect(flags[i].toString(), flagList.flags[i].toString());
        expectedFlags.remove(flags[i].toString());
      }
      expect(
        expectedFlags.length,
        0,
        reason: 'Value of expectedFlags is $expectedFlags',
      );

      await env.tearDownEnvironment(force: true);
    });
  }, timeout: const Timeout.factor(8));
  // TODO: Add a test that uses DartVM instead of Flutter
}
