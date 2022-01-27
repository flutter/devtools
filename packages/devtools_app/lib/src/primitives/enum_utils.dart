// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// Class that converts enum value names to enum entries and vice versa.
///
/// Example usage:
/// enum Color {
///   red, green, blue
/// }
/// ```
///   EnumUtils<Color> colorUtils = EnumUtils(Color.values);
///   colorUtils.getEnum('red'); // returns Color.red
///   colorUtils.getName(Color.red); // returns 'red'
/// ```
class EnumUtils<T> {
  EnumUtils(List<T> enumValues) {
    for (var val in enumValues) {
      final enumDescription = describeEnum(val);
      _lookupTable[enumDescription] = val;
      _reverseLookupTable[val] = enumDescription;
    }
  }

  final Map<String, T> _lookupTable = {};
  final Map<T, String> _reverseLookupTable = {};

  T enumEntry(String enumName) => _lookupTable[enumName];

  String name(T enumEntry) => _reverseLookupTable[enumEntry];
}
