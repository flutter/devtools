// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/profiler/profile_granularity.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_app/src/ui/flutter/vm_flag_widgets.dart';
import 'package:devtools_app/src/vm_flags.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  group('Profile Granularity Dropdown', () {
    FakeServiceManager fakeServiceManager;
    ProfileGranularityDropdown dropdown;

    setUp(() {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      dropdown = ProfileGranularityDropdown();
    });

    testWidgets('displays with default content', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(dropdown));
      expect(find.byWidget(dropdown), findsOneWidget);
      expect(
        find.byKey(ProfileGranularityDropdown.dropdownKey),
        findsOneWidget,
      );
      expect(find.text(ProfileGranularity.low.display), findsOneWidget);
      expect(find.text(ProfileGranularity.medium.display), findsOneWidget);
      expect(find.text(ProfileGranularity.high.display), findsOneWidget);
      final DropdownButton dropdownButton =
          tester.widget(find.byKey(ProfileGranularityDropdown.dropdownKey));
      expect(dropdownButton.value, equals(ProfileGranularity.medium.value));
    });

    testWidgets('selection', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(dropdown));
      expect(find.byWidget(dropdown), findsOneWidget);
      expect(find.text(ProfileGranularity.low.display), findsOneWidget);
      expect(find.text(ProfileGranularity.medium.display), findsOneWidget);
      expect(find.text(ProfileGranularity.high.display), findsOneWidget);
      DropdownButton dropdownButton =
          tester.widget(find.byKey(ProfileGranularityDropdown.dropdownKey));
      expect(dropdownButton.value, equals(ProfileGranularity.medium.value));

      var flagList = (await fakeServiceManager.service.getFlagList()).flags;
      expect(flagList, isEmpty);

      // Switch to low granularity.
      await tester.tap(find.byKey(ProfileGranularityDropdown.dropdownKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProfileGranularity.low.display).last);
      await tester.pumpAndSettle();
      dropdownButton =
          tester.widget(find.byKey(ProfileGranularityDropdown.dropdownKey));
      expect(dropdownButton.value, equals(ProfileGranularity.low.value));

      flagList = (await fakeServiceManager.service.getFlagList()).flags;
      var profilePeriodFlag = flagList[0];
      expect(profilePeriodFlag.name, equals(profilePeriod));
      expect(
        profilePeriodFlag.valueAsString,
        equals(ProfileGranularity.low.value),
      );

      // Switch to high granularity.
      await tester.tap(find.byKey(ProfileGranularityDropdown.dropdownKey));
      await tester.pumpAndSettle(); // finish the menu animation
      await tester.tap(find.text(ProfileGranularity.high.display).last);
      await tester.pumpAndSettle(); // finish the menu animation
      dropdownButton =
          tester.widget(find.byKey(ProfileGranularityDropdown.dropdownKey));
      expect(dropdownButton.value, equals(ProfileGranularity.high.value));

      flagList = (await fakeServiceManager.service.getFlagList()).flags;
      profilePeriodFlag = flagList[0];
      expect(profilePeriodFlag.name, equals(profilePeriod));
      expect(
        profilePeriodFlag.valueAsString,
        equals(ProfileGranularity.high.value),
      );
    });
  });
}
