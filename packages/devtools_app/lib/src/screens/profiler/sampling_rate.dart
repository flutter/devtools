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

enum CpuSamplingRate {
  low('CPU sampling rate: low', 'Low', lowProfilePeriod),
  medium('CPU sampling rate: medium', 'Medium', mediumProfilePeriod),
  high('CPU sampling rate: high', 'High', highProfilePeriod);

  const CpuSamplingRate(this.display, this.displayShort, this.value);

  final String display;

  final String displayShort;

  final String value;
}

extension CpuSamplingRateExtension on CpuSamplingRate {
  static CpuSamplingRate fromValue(String value) {
    switch (value) {
      case lowProfilePeriod:
        return CpuSamplingRate.low;
      case highProfilePeriod:
        return CpuSamplingRate.high;
      case mediumProfilePeriod:
      default:
        return CpuSamplingRate.medium;
    }
  }
}
