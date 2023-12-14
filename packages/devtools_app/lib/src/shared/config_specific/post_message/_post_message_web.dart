// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';

import 'package:web/helpers.dart';

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage {
  return window.onMessage.map(
    (message) => PostMessageEvent(
      origin: message.origin,
      data: message.data,
    ),
  );
}

void postMessage(Object? message, String targetOrigin) =>
    window.parent?.postMessage(message.jsify(), targetOrigin.toJS);
