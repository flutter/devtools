// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

/// A shim that imitates the interface of SseClient from package:sse.
///
/// This allows us to run DevTools with Flutter Desktop.
// TODO(https://github.com/flutter/devtools/issues/1122): Make SSE work without dart:html.
class SseClient {
  SseClient(String endpoint, {String? debugKey});

  Stream? get stream => null;

  StreamSink? get sink => null;
}
