// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:devtools_app_shared/web_utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:web/web.dart';

import 'api/model.dart';

const _opaqueOrigin = 'null';

Uri? _tryParseCanonicalHttpOrigin(String origin) {
  if (origin.isEmpty || origin == _opaqueOrigin) return null;

  final uri = Uri.tryParse(origin);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }

  try {
    if (uri.origin != origin) return null;
  } on StateError {
    return null;
  }

  return uri;
}

/// Returns whether [origin] is an allowed DevTools host origin for receiving
/// `postMessage` events in a DevTools extension.
///
/// Requires both [origin] and [windowOrigin] to be canonical HTTP(S) origins
/// (rejecting empty, opaque `'null'`, non-HTTP(S), and malformed origins).
/// Accepts [origin] when it equals [windowOrigin], or when both [origin] and
/// [windowOrigin] are loopback HTTP(S) origins (such as `http://localhost:<port>`
/// and `http://127.0.0.1:<port>` during local development).
bool isAllowedDevToolsOrigin(String origin, {required String windowOrigin}) {
  final originUri = _tryParseCanonicalHttpOrigin(origin);
  final windowOriginUri = _tryParseCanonicalHttpOrigin(windowOrigin);
  if (originUri == null || windowOriginUri == null) return false;

  if (origin == windowOrigin) return true;

  return isLoopbackHost(windowOriginUri.host) && isLoopbackHost(originUri.host);
}

DevToolsExtensionEvent? tryParseExtensionEvent(Event e) {
  if (e.isMessageEvent) {
    final messageData = (e as MessageEvent).data.dartify();
    if (messageData != null) {
      return DevToolsExtensionEvent.tryParse(messageData);
    }
  }
  return null;
}
