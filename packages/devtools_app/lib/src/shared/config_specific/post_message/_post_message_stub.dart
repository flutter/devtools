// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage =>
    throw UnsupportedError('unsupported platform');

// ignore: unused-code, the web implementation is a useful helper for posting messages on the window's parent; this stub is necessary for conditional imports.
void postMessage(Object? _, String _) =>
    throw UnsupportedError('unsupported platform');
