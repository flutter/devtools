// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

bool promptToLoadFallbackApp(String message) {
  final loadFallback = html.window.confirm(message);
  if (loadFallback) {
    var uri = Uri.parse(html.window.location.toString());
    uri = uri.replace(path: 'index_fallback.html');
    html.window.location.replace(uri.toString());
  }
  return loadFallback;
}
