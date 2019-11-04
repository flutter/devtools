// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../globals.dart';
import '../../vm_flags.dart' as vm_flags;

/// DropdownButton that controls the value of the 'profile_period' vm flag.
///
/// This flag controls the rate at which the vm samples the CPU call stack.
class ProfileGranularityDropdown extends StatefulWidget {
  @override
  ProfileGranularityDropdownState createState() =>
      ProfileGranularityDropdownState();
}

// TODO(kenz): listen for updates to 'profile_period' flag and update the
// dropdown accordingly. See https://github.com/flutter/devtools/issues/810 and
// https://github.com/flutter/devtools/issues/988.
class ProfileGranularityDropdownState
    extends State<ProfileGranularityDropdown> {
  String dropdownValue = ProfileGranularity.medium.value;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
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

  void _onProfileGranularityChanged(String newValue) {
    if (dropdownValue == newValue) return;
    serviceManager.service.setFlag(vm_flags.profilePeriod, newValue);
    setState(() {
      dropdownValue = newValue;
    });
  }
}

enum ProfileGranularity {
  low,
  medium,
  high,
}

extension ProfileGranularityExtension on ProfileGranularity {
  String get display {
    switch (this) {
      case ProfileGranularity.low:
        return 'Profile granularity: low';
      case ProfileGranularity.medium:
        return 'Profile granularity: medium';
      case ProfileGranularity.high:
      default:
        return 'Profile granularity: high';
    }
  }

  String get value {
    switch (this) {
      case ProfileGranularity.low:
        return '1000';
      case ProfileGranularity.medium:
        return '250';
      case ProfileGranularity.high:
      default:
        return '50';
    }
  }
}
