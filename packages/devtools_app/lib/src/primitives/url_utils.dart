// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(kenz): try to eliminate this method once
// https://github.com/dart-lang/sdk/issues/46872 is fixed.
/// Returns a simplified version of a package url, replacing "path/to/flutter"
/// with "package:".
///
/// This is a bit of a hack, as we have file paths instead of the explicit
/// "package:uris" we'd like to have. This will be problematic for a use case
/// such as "packages/my_package/src/utils/packages/flutter/".
String getSimplePackageUrl(String url) {
  const newFlutterPackagePrefix = 'package:flutter/';
  const originalFlutterPackagePrefix = 'packages/flutter/lib/src/';
  final flutterPrefixIndex = url.indexOf(originalFlutterPackagePrefix);

  const newDartPrefix = 'dart:';
  const originalDartPrefix = 'org-dartlang-sdk:///third_party/dart/sdk/lib/';
  final dartPrefixIndex = url.indexOf(originalDartPrefix);

  const newDartUiPrefix = 'dart:ui';
  const originalDartUiPrefix = 'org-dartlang-sdk:///flutter/lib/ui';
  final dartUiPrefixIndex = url.indexOf(originalDartUiPrefix);

  if (flutterPrefixIndex != -1) {
    return newFlutterPackagePrefix +
        url.substring(flutterPrefixIndex + originalFlutterPackagePrefix.length);
  } else if (dartPrefixIndex != -1) {
    return newDartPrefix +
        url.substring(dartPrefixIndex + originalDartPrefix.length);
  } else if (dartUiPrefixIndex != -1) {
    return newDartUiPrefix +
        url.substring(dartUiPrefixIndex + originalDartUiPrefix.length);
  }
  return url;
}
