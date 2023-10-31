// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';
import 'package:js/js_util.dart' as js;
import 'package:web/web.dart';

void copyToClipboardVSCode(String data) {
  final message = js.newObject();
  js.setProperty(message, 'command', 'clipboard-write');
  js.setProperty(message, 'data', data);

  // This post message is only relevant in VSCode. If the parent frame is
  // listening for this command, then it will attempt to copy the contents
  // to the clipboard in the context of the parent frame.
  window.parent?.postMessage(
    message,
    '*'.toJS,
  );
}
