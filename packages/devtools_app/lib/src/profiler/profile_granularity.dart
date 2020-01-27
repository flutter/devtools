// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Low 'profile_period' value.
///
/// When this value is applied to the 'profile_period' VM flag, the VM will
/// collect one sample every millisecond.
const lowProfilePeriod = '1000';

/// Medium 'profile_period' value.
///
/// When this value is applied to the 'profile_period' VM flag, the VM will
/// collect one sample every 250 microseconds.
const mediumProfilePeriod = '250';

/// High 'profile_period' value.
///
/// When this value is applied to the 'profile_period' VM flag, the VM will
/// collect one sample every 50 microseconds.
const highProfilePeriod = '50';

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
        return lowProfilePeriod;
      case ProfileGranularity.medium:
        return mediumProfilePeriod;
      case ProfileGranularity.high:
      default:
        return highProfilePeriod;
    }
  }

  static ProfileGranularity fromValue(String value) {
    switch (value) {
      case lowProfilePeriod:
        return ProfileGranularity.low;
      case highProfilePeriod:
        return ProfileGranularity.high;
      case mediumProfilePeriod:
      default:
        return ProfileGranularity.medium;
    }
  }
}
