// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// When to have verbose Dropdown based on media width.
const verboseDropDownMinimumWidth = 950;

const _memoryDocUrl =
    'https://docs.flutter.dev/development/tools/devtools/memory';

enum DocLinks {
  chart(_memoryDocUrl, 'expandable-chart'),
  profile(_memoryDocUrl, 'profile-tab'),
  diff(_memoryDocUrl, 'diff-tab'),
  trace(_memoryDocUrl, 'trace-tab'),
  ;

  const DocLinks(this.url, this.hash);

  final String url;
  final String hash;
  String get value => '$url#$hash';
}
