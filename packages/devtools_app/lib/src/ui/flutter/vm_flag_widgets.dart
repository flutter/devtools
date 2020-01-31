// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../profiler/cpu_profile_service.dart';
import '../../profiler/profile_granularity.dart';

/// DropdownButton that controls the value of the 'profile_period' vm flag.
///
/// This flag controls the rate at which the vm samples the CPU call stack.
class ProfileGranularityDropdown extends StatefulWidget {
  @override
  ProfileGranularityDropdownState createState() =>
      ProfileGranularityDropdownState();

  /// The key to identify the dropdown button.
  @visibleForTesting
  static const Key dropdownKey =
      Key('ProfileGranularityDropdown DropdownButton');
}

class ProfileGranularityDropdownState
    extends State<ProfileGranularityDropdown> {
  final profilerService = CpuProfilerService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Flag>(
      valueListenable: profilerService.profileGranularityFlagNotifier,
      builder: (context, flag, _) {
        // Use [ProfileGranularityExtension.fromValue] here so we can
        // guarantee that the value corresponds to one of the items in the
        // dropdown list. We default to [ProfileGranularity.medium] if the flag
        // value is not one of the three defaults in DevTools (50, 250, 1000).
        final safeValue =
            ProfileGranularityExtension.fromValue(flag.valueAsString).value;
        // Set the vm flag value to the [safeValue] if we get to this state.
        if (safeValue != flag.valueAsString) {
          _onProfileGranularityChanged(safeValue);
        }
        return DropdownButton<String>(
          key: ProfileGranularityDropdown.dropdownKey,
          value: safeValue,
          items: [
            _buildMenuItem(ProfileGranularity.low),
            _buildMenuItem(ProfileGranularity.medium),
            _buildMenuItem(ProfileGranularity.high),
          ],
          onChanged: _onProfileGranularityChanged,
        );
      },
    );
  }

  DropdownMenuItem _buildMenuItem(ProfileGranularity granularity) {
    return DropdownMenuItem<String>(
      value: granularity.value,
      child: Text(granularity.display),
    );
  }

  // TODO(kenz): show a warning when ProfileGranularity.high is selected.
  void _onProfileGranularityChanged(String newValue) {
    profilerService.setProfilePeriod(newValue);
  }
}
