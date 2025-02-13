// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:devtools_app_shared/web_utils.dart';
import 'package:web/web.dart';

import 'api/model.dart';

DevToolsExtensionEvent? tryParseExtensionEvent(Event e) {
  if (e.isMessageEvent) {
    final messageData = (e as MessageEvent).data.dartify()!;
    return DevToolsExtensionEvent.tryParse(messageData);
  }
  return null;
}
