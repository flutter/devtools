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

/// Extracts the current DevTools page from the given [url].
String extractCurrentPageFromUrl(String url) {
  // The url can be in one of two forms:
  // - /page?uri=xxx
  // - /?page=xxx&uri=yyy (original formats IDEs may use)
  // Use the path in preference to &page= as it's the one DevTools is updating
  final uri = Uri.parse(url);
  return uri.path == '/'
      ? uri.queryParameters['page'] ?? ''
      : uri.path.substring(1);
}

/// Maps DevTools URLs in the original fragment format onto the equivalent URLs
/// in the new URL format.
///
/// Returns `null` if [url] is not a legacy URL.
String? mapLegacyUrl(String url) {
  final uri = Uri.parse(url);
  // Old formats include:
  //   http://localhost:123/#/inspector?uri=ws://...
  //   http://localhost:123/#/?page=inspector&uri=ws://...
  final isRootRequest = uri.path == '/' || uri.path.endsWith('/devtools/');
  if (isRootRequest && uri.fragment.isNotEmpty) {
    final basePath = uri.path;
    // Convert the URL by removing the fragment separator.
    final newUrl = url
        // Handle localhost:123/#/inspector?uri=xxx
        .replaceFirst('/#/', '/')
        // Handle localhost:123/#?page=inspector&uri=xxx
        .replaceFirst('/#', '');

    // Move page names from the querystring into the path.
    var newUri = Uri.parse(newUrl);
    final page = newUri.queryParameters['page'];
    if (newUri.path == basePath && page != null) {
      final newParams = {...newUri.queryParameters}..remove('page');
      newUri = newUri.replace(
        path: '$basePath$page',
        queryParameters: newParams,
      );
    }
    return newUri.toString();
  }

  return null;
}
