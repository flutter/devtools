// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

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

// TODO(kenz): listen for updates to 'profile_period' flag and update the
// dropdown accordingly. See https://github.com/flutter/devtools/issues/810 and
// https://github.com/flutter/devtools/issues/988.
class ProfileGranularityDropdownState
    extends State<ProfileGranularityDropdown> {
  final profilerService = CpuProfilerService();

  String dropdownValue = ProfileGranularity.medium.value;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      key: ProfileGranularityDropdown.dropdownKey,
      value: dropdownValue,
      items: [
        _buildMenuItem(ProfileGranularity.low),
        _buildMenuItem(ProfileGranularity.medium),
        _buildMenuItem(ProfileGranularity.high),
      ],
      onChanged: _onProfileGranularityChanged,
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
    if (dropdownValue == newValue) return;
    profilerService.setProfilePeriod(newValue);
    setState(() {
      dropdownValue = newValue;
    });
  }
}
