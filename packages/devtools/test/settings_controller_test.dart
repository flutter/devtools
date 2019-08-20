// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

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

      bool isOnFlutter = false;
      List<Flag> flags = [];
      settingsController =
          SettingsController(onIsAnyFlutterAppReady: (isAnyFlutterApp) {
        isOnFlutter = isAnyFlutterApp;
      }, onFlagListReady: (flagList) {
        flags = flagList.flags;
      });
      expect(isOnFlutter, false);
      expect(flags, []);
      await settingsController.entering();
      expect(isOnFlutter, true);

      final flagList = await env.service.getFlagList();
      expect(flags.length, flagList.flags.length);
      for (var i = 0; i < flags.length; i++) {
        expect(flags[i].toString(), flagList.flags[i].toString());
      }
    });
  }, tags: 'useFlutterSdk');
}
