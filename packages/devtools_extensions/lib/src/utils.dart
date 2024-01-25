// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

import 'package:devtools_app_shared/web_utils.dart';
import 'package:web/web.dart';

import '../api.dart';

DevToolsExtensionEvent? tryParseExtensionEvent(Event e) {
  if (e.isMessageEvent) {
    final messageData = (e as MessageEvent).data.dartify()!;
    return DevToolsExtensionEvent.tryParse(messageData);
  }
  return null;
}
