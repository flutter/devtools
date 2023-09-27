// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// A shim that imitates the interface of SseClient from package:sse.
///
/// This allows us to run DevTools in environments that don't have dart:html
/// available, like the Flutter desktop embedder.
// TODO(https://github.com/flutter/devtools/issues/1122): Make SSE work without dart:html.
class SseClient {
  SseClient(String endpoint, {String? debugKey});

  Stream? get stream => null;

  StreamSink? get sink => null;
}
