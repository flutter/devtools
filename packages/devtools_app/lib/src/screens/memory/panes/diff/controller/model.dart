// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ClassFilterType {
  all,
  except,
  only,
}

class ClassFilter {
  ClassFilter(this.filterType, this.except, this.only);

  ClassFilter.empty() : this(ClassFilterType.all, '', '');

  final ClassFilterType filterType;
  final String except;
  final String only;

  bool get isEmpty =>
      filterType == ClassFilterType.all ||
      (filterType == ClassFilterType.except && except.trim().isEmpty) ||
      (filterType == ClassFilterType.only && only.trim().isEmpty);

  String get buttonTooltip {
    if (isEmpty) return 'Filter classes and packages.';
    return 'Not implemented yet';
  }
}
