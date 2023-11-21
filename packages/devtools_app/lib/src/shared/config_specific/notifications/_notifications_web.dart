// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';

import 'package:web/helpers.dart' as web_helpers;
import 'package:web/web.dart';

class Notification {
  Notification(String title, {String body = ''}) {
    _impl = web_helpers.Notification(
      title,
      NotificationOptions(body: body),
    );
  }

  late final web_helpers.Notification _impl;

  static Future<String> requestPermission() async =>
      ((await web_helpers.Notification.requestPermission().toDart) as JSString)
          .toDart;

  void close() {
    _impl.close();
  }
}
