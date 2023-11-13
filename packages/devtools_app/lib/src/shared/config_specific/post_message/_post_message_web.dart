// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// TODO(https://github.com/flutter/devtools/issues/6606): remove this import.
// This is the final dart:html import in DevTools. In order to remove it, we
// need to bump the `package:web` version in DevTools to > 0.3.1, but we are
// blocked on `package:web` rolling into the Flutter SDK.
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:web/helpers.dart';

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage {
  return html.window.onMessage.map(
    (message) => PostMessageEvent(
      origin: message.origin,
      data: message.data,
    ),
  );
}

void postMessage(Object? message, String targetOrigin) =>
    window.parent?.postMessage(message.jsify(), targetOrigin.toJS);
