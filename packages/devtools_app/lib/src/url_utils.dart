// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Returns a simplified version of a package url, replacing "path/to/flutter"
/// with "package:".
///
/// This is a bit of a hack, as we have file paths instead of the explicit
/// "package:uris" we'd like to have. This will be problematic for a use case
/// such as "packages/my_package/src/utils/packages/flutter/".
String getSimplePackageUrl(String url) {
  const newPackagePrefix = 'package:';
  const originalPackagePrefix = 'packages/';

  const flutterPrefix = 'packages/flutter/';
  const flutterWebPrefix = 'packages/flutter_web/';
  final flutterPrefixIndex = url.indexOf(flutterPrefix);
  final flutterWebPrefixIndex = url.indexOf(flutterWebPrefix);

  if (flutterPrefixIndex != -1) {
    return newPackagePrefix +
        url.substring(flutterPrefixIndex + originalPackagePrefix.length);
  } else if (flutterWebPrefixIndex != -1) {
    return newPackagePrefix +
        url.substring(flutterWebPrefixIndex + originalPackagePrefix.length);
  }
  return url;
}

/// Returns a normalized vm service uri.
///
/// Removes trailing characters, trailing url fragments, and decodes urls that
/// were accidentally encoded.
///
/// For example, given a [value] of http://127.0.0.1:60667/72K34Xmq0X0=/#/vm,
/// this method will return the URI http://127.0.0.1:60667/72K34Xmq0X0=/.
///
/// Returns null if the [Uri] parsed from [value] is not [Uri.absolute]
/// (ie, it has no scheme or it has a fragment).
Uri normalizeVmServiceUri(String value) {
  value = value.trim();

  // Clean up urls that have a devtools server's prefix, aka:
  // http://127.0.0.1:9101?uri=http%3A%2F%2F127.0.0.1%3A56142%2FHOwgrxalK00%3D%2F
  const uriParamToken = '?uri=';
  if (value.contains(uriParamToken)) {
    value =
        value.substring(value.indexOf(uriParamToken) + uriParamToken.length);
  }

  // Cleanup encoded urls likely copied from the uri of an existing running
  // DevTools app.
  if (value.contains('%3A%2F%2F')) {
    value = Uri.decodeFull(value);
  }
  final uri = Uri.parse(value.trim()).removeFragment();
  if (!uri.isAbsolute) {
    return null;
  }
  if (uri.path.endsWith('/')) return uri;
  return uri.replace(path: uri.path);
}
