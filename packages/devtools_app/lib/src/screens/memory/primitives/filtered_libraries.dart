// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

const _collectionLibraryUri = 'package:collection';
const _intlLibraryUri = 'package:intl';
const _vectorMathLibraryUri = 'package:vector_math';

/// First two libraries are special e.g., dart:* and package:flutter*
const dartLibraryUriPrefix = 'dart:';
const flutterLibraryUriPrefix = 'package:flutter';

/// State of the libraries, wildcard included, filtered (shown or hidden).
/// groupBy uses this class to determine is the library should be filtered.
class FilteredLibraries {
  final List<String> _filteredLibraries = [
    dartLibraryUriPrefix,
    _collectionLibraryUri,
    flutterLibraryUriPrefix,
    _intlLibraryUri,
    _vectorMathLibraryUri,
  ];

  static String normalizeLibraryUri(Library library) {
    final uriParts = library.uri!.split('/');
    final firstPart = uriParts.first;
    if (firstPart.startsWith(dartLibraryUriPrefix)) {
      return dartLibraryUriPrefix;
    } else if (firstPart.startsWith(flutterLibraryUriPrefix)) {
      return flutterLibraryUriPrefix;
    } else {
      return firstPart;
    }
  }

  List<String> get librariesFiltered =>
      _filteredLibraries.toList(growable: false);

  bool get isDartLibraryFiltered =>
      _filteredLibraries.contains(dartLibraryUriPrefix);

  bool get isFlutterLibraryFiltered =>
      _filteredLibraries.contains(flutterLibraryUriPrefix);

  void clearFilters() {
    _filteredLibraries.clear();
  }

  void addFilter(String libraryUri) {
    _filteredLibraries.add(libraryUri);
  }

  void removeFilter(String libraryUri) {
    _filteredLibraries.remove(libraryUri);
  }

  // Keys in the libraries map is a normalized library name.
  List<String> sort() => _filteredLibraries..sort();

  bool isDartLibrary(Library library) =>
      library.uri!.startsWith(dartLibraryUriPrefix);

  bool isFlutterLibrary(Library library) =>
      library.uri!.startsWith(flutterLibraryUriPrefix);

  bool isDartLibraryName(String libraryName) =>
      libraryName.startsWith(dartLibraryUriPrefix);

  bool isFlutterLibraryName(String libraryName) =>
      libraryName.startsWith(flutterLibraryUriPrefix);

  bool isLibraryFiltered(String? libraryName) =>
      // Are dart:* libraries filtered and its a Dart library?
      (_filteredLibraries.contains(dartLibraryUriPrefix) &&
          isDartLibraryName(libraryName!)) ||
      // Are package:flutter* filtered and its a Flutter package?
      (_filteredLibraries.contains(flutterLibraryUriPrefix) &&
          isFlutterLibraryName(libraryName!)) ||
      // Is this library filtered?
      _filteredLibraries.contains(libraryName);
}
