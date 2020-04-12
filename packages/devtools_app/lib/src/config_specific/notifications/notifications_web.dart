// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:html' as html;

class Notification {
  Notification(String title, {String body}) {
    _impl = html.Notification(title, body: body);
  }

  html.Notification _impl;

  static Future<String> requestPermission() {
    return html.Notification.requestPermission();
  }

  void close() {
    _impl.close();
  }
}
