// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';
import 'package:web/web.dart';

void copyToClipboardVSCode(String data) {
  // This post message is only relevant in VSCode. If the parent frame is
  // listening for this command, then it will attempt to copy the contents
  // to the clipboard in the context of the parent frame.
  window.parent?.postMessage(
    {
      'command': 'clipboard-write',
      'data': data,
    }.jsify(),
    '*'.toJS,
  );
}
