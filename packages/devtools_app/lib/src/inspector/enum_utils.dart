// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/fake_flutter/fake_flutter.dart';

/// A class for getting an enum object from its name or vice versa
///  Will return null for invalid value
///
///
/// Example usage:
/// enum Color {
///   red, green, blue
/// }
/// ```
///   EnumUtils<Color> colorUtils = EnumUtils(Color.values);
///   colorUtils.getEnum('red'); -> Color.red
///   colorUtils.getName(Color.red); -> 'red'
/// ```
class EnumUtils<T> {
  // currently there's no way to
  EnumUtils(List<T> enumValues) {
    for (var val in enumValues) {
      final enumDescription = describeEnum(val);
      _lookupTable[enumDescription] = val;
      _reverseLookupTable[val] = enumDescription;
    }
  }

  final Map<String, T> _lookupTable = {};
  final Map<T, String> _reverseLookupTable = {};

  T getEnum(String value) => _lookupTable[value];

  String getName(T value) => _reverseLookupTable[value];
}
