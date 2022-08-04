// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/primitives/storage.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_storage.dart';

void main() {
  setGlobal(ServiceConnectionManager, FakeServiceManager());

  group('PreferencesController', () {
    late PreferencesController controller;

    setUp(() {
      controller = PreferencesController();
    });

    test('has value', () {
      expect(controller.darkModeTheme.value, isNotNull);
      expect(controller.denseModeEnabled.value, isNotNull);
    });

    test('toggleDarkModeTheme', () {
      bool valueChanged = false;
      final originalValue = controller.darkModeTheme.value;

      controller.darkModeTheme.addListener(() {
        valueChanged = true;
      });

      controller.toggleDarkModeTheme(!controller.darkModeTheme.value);
      expect(valueChanged, isTrue);
      expect(controller.darkModeTheme.value, isNot(originalValue));
    });

    test('toggleVmDeveloperMode', () {
      bool valueChanged = false;
      final originalValue = controller.vmDeveloperModeEnabled.value;

      controller.vmDeveloperModeEnabled.addListener(() {
        valueChanged = true;
      });

      controller
          .toggleVmDeveloperMode(!controller.vmDeveloperModeEnabled.value);
      expect(valueChanged, isTrue);
      expect(controller.vmDeveloperModeEnabled.value, isNot(originalValue));
    });

    test('toggleDenseMode', () {
      bool valueChanged = false;
      final originalValue = controller.denseModeEnabled.value;

      controller.denseModeEnabled.addListener(() {
        valueChanged = true;
      });

      controller.toggleDenseMode(!controller.denseModeEnabled.value);
      expect(valueChanged, isTrue);
      expect(controller.denseModeEnabled.value, isNot(originalValue));
    });
  });

  group('InspectorPreferencesController', () {
    group('hoverEvalMode', () {
      late InspectorPreferencesController controller;

      setUp(() async {
        setGlobal(Storage, FlutterTestStorage());
        setGlobal(IdeTheme, IdeTheme());
        controller = InspectorPreferencesController();
      });

      group('init', () {
        setUp(() {
          controller.setHoverEvalMode(false);
        });

        test('enables hover mode by default', () async {
          await controller.init();
          expect(controller.hoverEvalModeEnabled.value, isTrue);
        });

        test('when embedded, disables hover mode by default', () async {
          setGlobal(IdeTheme, IdeTheme(embed: true));
          await controller.init();
          expect(controller.hoverEvalModeEnabled.value, isFalse);
        });
      });

      test('can be updated', () async {
        await controller.init();

        var valueChanged = false;
        final newHoverModeValue = !controller.hoverEvalModeEnabled.value;
        controller.hoverEvalModeEnabled.addListener(() {
          valueChanged = true;
        });

        controller.setHoverEvalMode(newHoverModeValue);

        final storedHoverModeValue =
            await storage.getValue('inspector.hoverEvalMode');
        expect(valueChanged, isTrue);
        expect(controller.hoverEvalModeEnabled.value, newHoverModeValue);
        expect(
          storedHoverModeValue,
          newHoverModeValue.toString(),
        );
      });
    });
  });
}
