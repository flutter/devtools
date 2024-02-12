// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

class Notification {
  Notification(String title, {String body = ''}) {
    _impl = web.Notification(
      title,
      web.NotificationOptions(body: body),
    );
  }

  late final web.Notification _impl;

  static Future<String> requestPermission() async =>
      // TODO(srujzs): This was needed in 0.4.0 as generics were not available.
      // This is no longer true 0.5.0 onwards.
      // ignore: unnecessary_cast
      ((await web.Notification.requestPermission().toDart) as JSString).toDart;

  void close() {
    _impl.close();
  }
}
