// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

@TestOn('vm')
import 'package:devtools_app/src/shared/globals.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_infra/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'test_infra/flutter_test_environment.dart';

void main() async {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  group('VmFlagManager', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('flags initialized on vm service opened', () async {
      await env.setupEnvironment();

      expect(serviceManager.service, equals(env.service));
      expect(serviceManager.vmFlagManager, isNotNull);
      expect(serviceManager.vmFlagManager.flags.value, isNotNull);

      await env.tearDownEnvironment();
    }, timeout: const Timeout.factor(4));

    test('notifies on flag change', () async {
      await env.setupEnvironment();
      const profiler = 'profiler';

      final flagManager = serviceManager.vmFlagManager;
      final initialFlags = flagManager.flags.value;
      final profilerFlagNotifier = flagManager.flag(profiler)!;
      expect(profilerFlagNotifier.value.valueAsString, equals('true'));

      await serviceManager.service!.setFlag(profiler, 'false');
      expect(profilerFlagNotifier.value.valueAsString, equals('false'));

      // Await a delay so the new flags have time to be pulled and set.
      await Future.delayed(const Duration(milliseconds: 5000));
      final newFlags = flagManager.flags.value;
      expect(newFlags, isNot(equals(initialFlags)));

      await env.tearDownEnvironment();
    }, timeout: const Timeout.factor(4));
  });
}
