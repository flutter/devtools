// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export '_post_message_service_stub.dart'
    if (dart.library.js_interop) '_post_message_service_web.dart';

/// Returns whether [uri] uses the `post-message:` or `postmessage:` scheme.
///
/// This scheme is used when DevTools is embedded in an `<iframe>` and
/// communicates with the target Dart/Flutter application via a transferred
/// `MessagePort` instead of a WebSocket or SSE connection.
bool isPostMessageUri(Uri uri) =>
    uri.scheme == 'post-message' || uri.scheme == 'postmessage';
