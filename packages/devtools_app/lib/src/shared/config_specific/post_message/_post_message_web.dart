// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, workaround for https://github.com/dart-lang/sdk/issues/54938
import 'dart:html' as html;
import 'dart:js_interop';

import 'package:web/web.dart';

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage {
  return window.onMessage.map(
    (message) => PostMessageEvent(
      origin: message.origin,
      data: message.data.dartify(),
    ),
  );
}

void postMessage(Object? message, String targetOrigin) =>
    // TODO(dantup): Switch back to package:web version of this code once
    //  https://github.com/dart-lang/sdk/issues/54938 is fixed.
    //
    // package:web version:
    //   window.parent?.postMessage(message.jsify(), targetOrigin.toJS);
    // legacy dart:html version:
    html.window.parent?.postMessage(message, targetOrigin);
