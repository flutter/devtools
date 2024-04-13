// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/framework/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/control/widgets/settings_dialog.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app_shared/src/ui/dialogs.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/matchers/matchers.dart';
import '../../test_infra/scenes/memory/default.dart';
import '../../test_infra/scenes/scene_test_extensions.dart';

void main() {
  late MemoryDefaultScene scene;

  Future<void> pumpMemoryScreen(WidgetTester tester) async {
    await tester.pumpSceneAsync(scene);
    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  setUp(() async {
    scene = MemoryDefaultScene();
    await scene.setUp();
  });

  tearDown(() {
    scene.tearDown();
  });

  testWidgetsWithWindowSize(
    'settings update preferences',
    windowSize,
    (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Open the dialog.
      await tester.tap(find.byType(SettingsOutlinedButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MemorySettingsDialog),
        matchesDevToolsGolden(
          '../../test_infra/goldens/settings_dialog_default.png',
        ),
      );

      // Modify settings and check the changes are reflected in the controller.
      expect(
        preferences.memory.androidCollectionEnabled.value,
        isFalse,
      );
      await tester
          .tap(find.byKey(MemorySettingDialogKeys.showAndroidChartCheckBox));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MemorySettingsDialog),
        matchesDevToolsGolden(
          '../../test_infra/goldens/settings_dialog_modified.png',
        ),
      );
      expect(
        preferences.memory.androidCollectionEnabled.value,
        isTrue,
      );

      // Reopen the dialog and check the settings are not changed.
      await tester.tap(find.byType(DialogCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SettingsOutlinedButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MemorySettingsDialog),
        matchesDevToolsGolden(
          '../../test_infra/goldens/settings_dialog_modified.png',
        ),
      );
    },
  );
}
