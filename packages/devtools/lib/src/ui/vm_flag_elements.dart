// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../framework/framework.dart';
import '../globals.dart';
import '../messages.dart';
import 'primer.dart';

class ProfileGranularitySelector {
  ProfileGranularitySelector(this.framework) {
    selector = PSelect()
      ..small()
      ..clazz('button-bar-selector')
      ..change(_handleSelect)
      ..tooltip = 'Granularity of CPU profiling. For a finer-grained profile, '
          'choose "Profile granularity: high". Please read our documentation to'
          ' understand the trade-offs associated with this setting.'
      ..option('Profile granularity: low', value: '1000')
      ..option('Profile granularity: medium', value: '250')
      ..option('Profile granularity: high', value: highGranularityValue);

    // Select 250 μs (the default profile period).
    selector.selectedIndex = defaultSelectedIndex;
  }

  static const defaultSelectedIndex = 1;

  static const highGranularityValue = '50';

  final Framework framework;

  PSelect selector;

  String _selectedValue;

  Future<void> setGranularity() async {
    return serviceManager.service.setFlag('profile_period', selector.value);
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
