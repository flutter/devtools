// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(terry): Ask Ben, what is a class name of ::?
/// Internal class names :: automatically filter out.
const internalClassName = '::';

/// Contains normalized library name and class name. Where
/// normalized library is dart:xxx, package:xxxx, etc. This is
/// how libraries and class names are displayed to the user
/// to help to reduce the 100s of URIs that would otherwise be
/// encountered.
class LibraryClass {
  LibraryClass(this.libraryName, this.className);

  final String libraryName;
  final String className;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != LibraryClass) return false;
    return libraryName == other.libraryName && className == other.className;
  }

  @override
  int get hashCode => libraryName.hashCode ^ className.hashCode;
}

const core = 'dart:core';
const collection = 'dart:collection';

// TODO(terry): Bake in types instead of comparing qualified class name.
LibraryClass predefinedNull = LibraryClass(core, 'Null');
LibraryClass predefinedString = LibraryClass(core, '_OneByteString');
LibraryClass predefinedList = LibraryClass(core, '_List');
LibraryClass predefinedMap = LibraryClass(
  collection,
  '_InternalLinkedHashMap',
);

LibraryClass predefinedHashMap = LibraryClass(
  collection,
  '_HashMap',
);

class Predefined {
  const Predefined(this.prettyName, this.isScalar);

  final String prettyName;
  final bool isScalar;
}

/// Structure key is fully qualified class name and the value is
/// a List first entry is pretty name known to users second entry
/// is if the type is a scalar.
Map<LibraryClass, Predefined> predefinedClasses = {
  LibraryClass(core, 'bool'): const Predefined('bool', true),
  // TODO(terry): Handle Smi too (Integer)?
  // Integers not Smi but fit into 64bits.
  LibraryClass(core, '_Mint'): const Predefined('int', true),
  LibraryClass(core, '_Double'): const Predefined('Double', true),
  predefinedString: const Predefined('String', true),
  predefinedList: const Predefined('List', false),
  predefinedMap: const Predefined('Map', false),
  predefinedHashMap: const Predefined('HashMap', false),
  predefinedNull: const Predefined('Null', true),
};
