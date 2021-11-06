// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreferencesController', () {
    PreferencesController controller;

    setUp(() {
      controller = PreferencesController();
    });

    test('has value', () {
      expect(controller.darkModeTheme.value, isNotNull);
      expect(controller.denseModeEnabled.value, isNotNull);
      expect(controller.splitFractions, isNotNull);
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

    test('updateSplitFractions', () {
      bool valueChanged = false;
      const String fractionsKey = 'test';
      const List<double> testValue = [0.33342342423, 0.98989899343];
      const List<double> testValue2 = [0.33342342424, 0.98989899344];
      final originalValue = controller.lookupSplitFractions(fractionsKey).value;

      controller.lookupSplitFractions(fractionsKey).addListener(() {
        valueChanged = true;
      });

      controller.updateSplitFractions(fractionsKey, testValue);
      expect(valueChanged, isTrue);
      expect(controller.lookupSplitFractions(fractionsKey).value,
          isNot(originalValue));

      valueChanged = false;
      controller.updateSplitFractions(fractionsKey, testValue);
      expect(valueChanged, isFalse);

      controller.updateSplitFractions(fractionsKey, testValue2);
      expect(valueChanged, isTrue);
      expect(
          controller.isListEqual(
              controller.lookupSplitFractions(fractionsKey).value, testValue2),
          isTrue);
    });
  });
}
