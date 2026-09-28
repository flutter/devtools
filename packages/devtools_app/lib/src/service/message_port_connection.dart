// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export '_message_port_connection_stub.dart'
    if (dart.library.js_interop) '_message_port_connection_web.dart';

/// URI scheme for connecting to a VM service over a [`MessagePort`][1] from
/// the page embedding DevTools.
///
/// For `?uri=messageport:<targetOrigin>`, DevTools sends a new `port` to the
/// embedding page on every connect, including reconnects and reloads:
///
/// ```js
/// window.parent.postMessage({action: 'connect', port}, targetOrigin, [port]);
/// ```
///
/// * `targetOrigin`: the embedding page's origin, or `*`. Browsers silently
///   drop the message on a mismatch.
/// * `port`: the embedding page connects it to a VM service. Messages are
///   [VM service protocol][2] JSON-RPC strings, or binary frames as
///   `Uint8Array`.
/// * Only the latest `port` is used; older ones may be closed.
///
/// [1]: https://developer.mozilla.org/en-US/docs/Web/API/MessagePort
/// [2]: https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md
const messagePortUriScheme = 'messageport';

/// Whether [uri] has the [messagePortUriScheme].
bool isMessagePortUri(Uri uri) => uri.isScheme(messagePortUriScheme);
