// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../globals.dart';
import 'primer.dart';

class SamplePeriodSelector {
  SamplePeriodSelector() {
    selector = PSelect()
      ..small()
      ..clazz('on-page-selector')
      ..change(_handleSelect)
      ..tooltip = 'The frequency at which the VM will collect CPU samples. For '
          'a finer-grained profile, choose a smaller sample period. Please '
          'read our documentation to understand the trade-offs associated with '
          'this setting.'
      ..option('Sample period: 1000 μs', value: '1000')
      ..option('Sample period: 500 μs', value: '500')
      ..option('Sample period: 250 μs', value: '250')
      ..option('Sample period: 150 μs', value: '150')
      ..option('Sample period: 50 μs', value: '50');

    // Select 250 μs (the default profile period).
    selector.selectedIndex = defaultSelectedIndex;
  }

  static const defaultSelectedIndex = 2;

  static const profilePeriodFlagName = 'profile_period';

  PSelect selector;

  String _selectedValue;

  Future<void> setSamplePeriod() async {
    return serviceManager.service
        .setFlag(profilePeriodFlagName, selector.value);
  }

  void _handleSelect() async {
    if (selector.value == _selectedValue) return;
    await setSamplePeriod();
    _selectedValue = selector.value;
  }
}
