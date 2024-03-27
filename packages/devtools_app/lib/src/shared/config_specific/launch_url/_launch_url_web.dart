// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import '../post_message/post_message.dart';

void launchUrlVSCode(String url) {
  postMessage(
    {
      'command': 'launchUrl',
      'data': {'url': url},
    },
    '*',
  );
}
