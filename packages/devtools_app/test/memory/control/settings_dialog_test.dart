// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/control/settings_dialog.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/dialogs.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../matchers/matchers.dart';
import '../../test_data/memory.dart';
import '../../test_data/memory_allocation.dart';

void main() {
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;
  late PreferencesController preferencesController;

  Future<void> pumpMemoryScreen(
    WidgetTester tester, {
    MemoryController? memoryController,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const MemoryBody(),
        memory: controller = memoryController ?? MemoryController(),
      ),
    );

    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  group('MemoryScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      setGlobal(OfflineModeController, OfflineModeController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
      setGlobal(
        PreferencesController,
        preferencesController = PreferencesController(),
      );

      // Load canned data testHeapSampleData.
      final memoryJson =
          SamplesMemoryJson.decode(argJsonString: testHeapSampleData);
      final allocationJson =
          AllocationMemoryJson.decode(argJsonString: testAllocationData);

      fakeServiceManager = FakeServiceManager(
        service: FakeServiceManager.createFakeService(
          memoryData: memoryJson,
          allocationData: allocationJson,
        ),
      );
      final app = fakeServiceManager.connectedApp!;
      mockConnectedApp(
        app,
        isFlutterApp: true,
        isProfileBuild: true,
        isWebApp: false,
      );
      setGlobal(ServiceConnectionManager, fakeServiceManager);

      controller = MemoryController()
        ..offline.value = true
        ..memoryTimeline.offlineData.clear()
        ..memoryTimeline.offlineData.addAll(memoryJson.data);
    });

    testWidgetsWithWindowSize('settings update preferences', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester, memoryController: controller);

      // Open the dialog.
      await tester.tap(find.byType(SettingsOutlinedButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MemorySettingsDialog),
        matchesDevToolsGolden('../../goldens/settings_dialog_default.png'),
      );

      // Modify settings and check the changes are reflected in the controller.
      expect(preferencesController.memory.autoSnapshotEnabled.value, isFalse);
      expect(preferencesController.memory.autoSnapshotEnabled.value, isFalse);
      await tester
          .tap(find.byKey(MemorySettingDialogKeys.showAndroidChartCheckBox));
      await tester
          .tap(find.byKey(MemorySettingDialogKeys.autoSnapshotCheckbox));
      expect(preferencesController.memory.autoSnapshotEnabled.value, isTrue);
      expect(preferencesController.memory.autoSnapshotEnabled.value, isTrue);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MemorySettingsDialog),
        matchesDevToolsGolden('../../goldens/settings_dialog_modified.png'),
      );

      // Reopen the dialog and check the settings are not changed.
      await tester.tap(find.byType(DialogCloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SettingsOutlinedButton));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MemorySettingsDialog),
        matchesDevToolsGolden('../../goldens/settings_dialog_modified.png'),
      );
    });
  });
}
