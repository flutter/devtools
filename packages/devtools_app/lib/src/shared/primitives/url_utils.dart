// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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

const _jsCompilerParam = '?compiler=js';
const _wasmCompilerParam = '?compiler=wasm';

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
    // Note: If there is a ?compiler= query parameter, we remove it from before
    // the hash then add it back in as a query parameter at the end.
    // See https://github.com/flutter/devtools/issues/9612 for details.
    final hasJsParam = url.contains(_jsCompilerParam);
    final hasWasmParam = url.contains(_wasmCompilerParam) && !hasJsParam;
    final basePath = uri.path;
    // Convert the URL by removing the fragment separator.
    final newUrl = url
        .replaceAll(_jsCompilerParam, '')
        .replaceAll(_wasmCompilerParam, '')
        // Handle localhost:123/#/inspector?uri=xxx
        .replaceFirst('/#/', '/')
        // Handle localhost:123/#?page=inspector&uri=xxx
        .replaceFirst('/#', '');

    // Move page names from the querystring into the path.
    var newUri = Uri.parse(newUrl);
    final queryParams = {
      ...newUri.queryParameters,
      if (hasJsParam) 'compiler': 'js',
      if (hasWasmParam) 'compiler': 'wasm',
    };
    newUri = newUri.replace(queryParameters: queryParams);
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
