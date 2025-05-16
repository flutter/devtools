// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'server.dart';

/// Checks whether the server HTTP API is available.
Future<bool> checkServerHttpApiAvailable() async {
  try {
    // Unlike other parts of this API, the ping request is handled directly
    // in the server in the SDK (see `pkg\dds\lib\src\devtools\handler.dart`)
    // and not delegated back to DevTools shared code.
    final response = await get(
      buildDevToolsServerRequestUri('${apiPrefix}ping'),
    ).timeout(const Duration(seconds: 5));
    // When running with the local dev server Flutter may serve its index page
    // for missing files to support the hashless url strategy. Check the response
    // content to confirm it came from our server.
    // See https://github.com/flutter/flutter/issues/67053
    if (response.statusCode != 200 || response.body != 'OK') {
      _log.info('DevTools server not available (${response.statusCode})');
      return false;
    }
  } catch (e) {
    // unable to locate dev server
    _log.info('DevTools server not available ($e)');
    return false;
  }

  return true;
}
