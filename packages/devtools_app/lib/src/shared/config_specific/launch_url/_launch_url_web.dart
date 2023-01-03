// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:html';

void launchUrlVSCode(String url) {
  window.parent?.postMessage(
    {
      'command': 'launchUrl',
      'data': {'url': url},
    },
    '*',
  );
}
