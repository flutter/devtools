// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export '_post_message_stub.dart'
    if (dart.library.js_interop) '_post_message_web.dart';

class PostMessageEvent {
  PostMessageEvent({required this.origin, required this.data});

  final String origin;
  final Object? data;
}
