// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/profiler/profile_granularity.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:devtools_app/src/ui/flutter/vm_flag_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('Profile Granularity Dropdown', () {
    testWidgets('displays with default content', (WidgetTester tester) async {
      final dropdown = ProfileGranularityDropdown();
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
  });
}
