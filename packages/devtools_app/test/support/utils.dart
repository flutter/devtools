// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Scoping method which registers `listener` as a listener for `listenable`,
/// invokes `callback`, and then removes the `listener`.
Future<void> addListenerScope(
  dynamic listenable,
  Function listener,
  Function callback,
) async {
  listenable.addListener(listener);
  await callback();
  listenable.removeListener(listener);
}
