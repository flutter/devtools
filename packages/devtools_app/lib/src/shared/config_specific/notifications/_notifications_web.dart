// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

class Notification {
  Notification(String title, {String body = ''}) {
    _impl = web.Notification(title, web.NotificationOptions(body: body));
  }

  late final web.Notification _impl;

  static Future<String> requestPermission() async =>
      (await web.Notification.requestPermission().toDart).toDart;

  void close() {
    _impl.close();
  }
}
