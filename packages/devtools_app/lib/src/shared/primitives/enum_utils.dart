// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
class EnumUtils<T extends Enum> {
  EnumUtils(List<T> enumValues) {
    for (final val in enumValues) {
      final enumDescription = val.name;
      _lookupTable[enumDescription] = val;
      _reverseLookupTable[val] = enumDescription;
    }
  }

  final _lookupTable = <String, T>{};
  final _reverseLookupTable = <T, String>{};

  T? enumEntry(String? enumName) =>
      enumName != null ? _lookupTable[enumName] : null;

  String? name(T enumEntry) => _reverseLookupTable[enumEntry];
}

mixin EnumIndexOrdering<T extends Enum> on Enum implements Comparable<T> {
  @override
  int compareTo(T other) => index.compareTo(other.index);

  bool operator <(T other) {
    return index < other.index;
  }

  bool operator >(T other) {
    return index > other.index;
  }

  bool operator >=(T other) {
    return index >= other.index;
  }

  bool operator <=(T other) {
    return index <= other.index;
  }
}
