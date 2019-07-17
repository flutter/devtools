// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import '../framework/framework.dart';
import '../globals.dart';
import '../messages.dart';
import 'primer.dart';

// TODO(kenzie): handle the multi-client case for this selector.

class ProfileGranularitySelector {
  ProfileGranularitySelector(this.framework) {
    selector = PSelect()
      ..small()
      ..clazz('button-bar-dropdown')
      ..change(_handleSelect)
      ..tooltip = 'Granularity of CPU profiling. For a finer-grained profile, '
          'choose "Profile granularity: high". Please read our documentation to'
          ' understand the trade-offs associated with this setting.'
      ..option('Profile granularity: low', value: lowGranularityValue)
      ..option('Profile granularity: medium', value: mediumGranularityValue)
      ..option('Profile granularity: high', value: highGranularityValue);

    // Select medium granularity (250 μs) as the default.
    selector.selectedIndex = mediumGranularityIndex;
  }

  static const profilePeriodFlagName = 'profile_period';

  static const lowGranularityValue = '1000';

  static const mediumGranularityValue = '250';

  static const highGranularityValue = '50';

  static const mediumGranularityIndex = 1;

  final Framework framework;

  PSelect selector;

  String _selectedValue;

  Future<void> setGranularity() async {
    return serviceManager.service
        .setFlag(profilePeriodFlagName, selector.value);
  }

  void _handleSelect() async {
    if (selector.value == _selectedValue) return;
    await setGranularity();
    _selectedValue = selector.value;

    if (selector.value == highGranularityValue) {
      framework.showMessage(message: profileGranularityWarning);
    }
  }
}
