// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app/src/screens/profiler/profiler_screen.dart';
import 'package:devtools_app/src/screens/profiler/sampling_rate.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/service/vm_flags.dart' as vm_flags;
import 'package:devtools_app/src/shared/banner_messages.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/theme.dart';
import 'package:devtools_app/src/shared/ui/vm_flag_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('Profile Granularity Dropdown', () {
    late FakeServiceManager fakeServiceManager;
    late CpuSamplingRateDropdown dropdown;
    late BuildContext buildContext;

    setUp(() async {
      fakeServiceManager = FakeServiceManager();
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
      await fakeServiceManager.flagsInitialized.future;
      dropdown = CpuSamplingRateDropdown(
        screenId: ProfilerScreen.id,
        profilePeriodFlagNotifier:
            fakeServiceManager.vmFlagManager.flag(vm_flags.profilePeriod)!,
      );
    });

    Future<void> pumpDropdown(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeFor(isDarkTheme: false, ideTheme: IdeTheme()),
          home: Material(
            child: wrapWithControllers(
              Builder(
                builder: (context) {
                  buildContext = context;
                  return dropdown;
                },
              ),
              bannerMessages: BannerMessagesController(),
            ),
          ),
        ),
      );
    }

    testWidgets('displays with default content', (WidgetTester tester) async {
      await pumpDropdown(tester);
      expect(find.byWidget(dropdown), findsOneWidget);
      expect(
        find.byKey(CpuSamplingRateDropdown.dropdownKey),
        findsOneWidget,
      );
      expect(find.text(CpuSamplingRate.low.display), findsOneWidget);
      expect(find.text(CpuSamplingRate.medium.display), findsOneWidget);
      expect(find.text(CpuSamplingRate.high.display), findsOneWidget);
      final RoundedDropDownButton<String> dropdownButton =
          tester.widget(find.byKey(CpuSamplingRateDropdown.dropdownKey));
      expect(dropdownButton.value, equals(CpuSamplingRate.medium.value));
    });

    testWidgets('selection', (WidgetTester tester) async {
      await pumpDropdown(tester);
      expect(find.byWidget(dropdown), findsOneWidget);
      expect(find.text(CpuSamplingRate.low.display), findsOneWidget);
      expect(find.text(CpuSamplingRate.medium.display), findsOneWidget);
      expect(find.text(CpuSamplingRate.high.display), findsOneWidget);
      RoundedDropDownButton<String> dropdownButton =
          tester.widget(find.byKey(CpuSamplingRateDropdown.dropdownKey));
      expect(dropdownButton.value, equals(CpuSamplingRate.medium.value));

      var profilePeriodFlag =
          (await getProfileGranularityFlag(fakeServiceManager))!;
      expect(
        profilePeriodFlag.valueAsString,
        equals(CpuSamplingRate.medium.value),
      );

      // Switch to high granularity.
      await tester.tap(find.byKey(CpuSamplingRateDropdown.dropdownKey));
      await tester.pumpAndSettle(); // finish the menu animation
      await tester.tap(find.text(CpuSamplingRate.high.display).last);
      await tester.pumpAndSettle(); // finish the menu animation
      dropdownButton =
          tester.widget(find.byKey(CpuSamplingRateDropdown.dropdownKey));
      expect(dropdownButton.value, equals(CpuSamplingRate.high.value));

      profilePeriodFlag =
          (await getProfileGranularityFlag(fakeServiceManager))!;
      expect(profilePeriodFlag.name, equals(vm_flags.profilePeriod));
      expect(
        profilePeriodFlag.valueAsString,
        equals(CpuSamplingRate.high.value),
      );
      // Verify we are showing the high profile granularity warning.
      expect(
        bannerMessagesController(buildContext)
            .messagesForScreen(ProfilerScreen.id)
            .value
            .length,
        equals(1),
      );

      // Switch to low granularity.
      await tester.tap(find.byKey(CpuSamplingRateDropdown.dropdownKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CpuSamplingRate.low.display).last);
      await tester.pumpAndSettle();
      dropdownButton =
          tester.widget(find.byKey(CpuSamplingRateDropdown.dropdownKey));
      expect(dropdownButton.value, equals(CpuSamplingRate.low.value));

      profilePeriodFlag =
          (await getProfileGranularityFlag(fakeServiceManager))!;
      expect(profilePeriodFlag.name, equals(vm_flags.profilePeriod));
      expect(
        profilePeriodFlag.valueAsString,
        equals(CpuSamplingRate.low.value),
      );
      // Verify we are not showing the high profile granularity warning.
      expect(
        bannerMessagesController(buildContext)
            .messagesForScreen(ProfilerScreen.id)
            .value,
        isEmpty,
      );
    });

    void testUpdatesForFlagChange(
      WidgetTester tester, {
      required String newFlagValue,
      required String expectedFlagValue,
    }) async {
      await pumpDropdown(tester);
      expect(find.byWidget(dropdown), findsOneWidget);
      final dropdownButtonFinder =
          find.byKey(CpuSamplingRateDropdown.dropdownKey);
      RoundedDropDownButton<String> dropdownButton =
          tester.widget(dropdownButtonFinder);
      expect(dropdownButton.value, equals(CpuSamplingRate.medium.value));

      await serviceManager.service!.setFlag(
        vm_flags.profilePeriod,
        newFlagValue,
      );
      await tester.pumpAndSettle();
      dropdownButton = tester.widget(dropdownButtonFinder);
      expect(dropdownButton.value, equals(expectedFlagValue));
    }

    testWidgets('updates value for safe flag change',
        (WidgetTester tester) async {
      testUpdatesForFlagChange(
        tester,
        newFlagValue: CpuSamplingRate.high.value,
        expectedFlagValue: CpuSamplingRate.high.value,
      );
    });

    testWidgets('updates value for unsafe flag change',
        (WidgetTester tester) async {
      // 999 is not a value in the dropdown list.
      testUpdatesForFlagChange(
        tester,
        newFlagValue: '999',
        expectedFlagValue: CpuSamplingRate.medium.value,
      );
    });
  });
}

BannerMessagesController bannerMessagesController(BuildContext context) {
  return Provider.of<BannerMessagesController>(context, listen: false);
}

Future<Flag?> getProfileGranularityFlag(
  FakeServiceManager serviceManager,
) async {
  final flagList = (await serviceManager.service!.getFlagList()).flags!;
  return flagList.firstWhereOrNull(
    (flag) => flag.name == vm_flags.profilePeriod,
  );
}
