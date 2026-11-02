// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export '_message_port_connection_stub.dart'
    if (dart.library.js_interop) '_message_port_connection_web.dart';

/// URI scheme for connecting to a VM service over a [`MessagePort`][1] from
/// the page embedding or opening DevTools.
///
/// For `?uri=messageport:<targetOrigin>`, DevTools sends a new `port` to its
/// embedder on every connect, including reconnects and reloads:
///
/// ```js
/// const embedder = window.opener ?? window.parent;
/// embedder.postMessage({action: 'connect', port}, targetOrigin, [port]);
/// ```
///
/// * `targetOrigin`: the embedder's origin, or `*`. Browsers silently drop the
///   message on a mismatch.
/// * `port`: the embedder connects it to a VM service. Messages are:
///   * [VM service protocol][2] JSON-RPC strings,
///   * binary frames as `Uint8Array`, or,
///   * `null` to close the connection.
/// * Only the latest `port` is used; older ones may be closed.
///
/// [1]: https://developer.mozilla.org/en-US/docs/Web/API/MessagePort
/// [2]: https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md
const messagePortUriScheme = 'messageport';

/// Whether [uri] has the [messagePortUriScheme].
bool isMessagePortUri(Uri uri) => uri.isScheme(messagePortUriScheme);
