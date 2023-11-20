// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_util';

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

  static Future<String> requestPermission() {
    return promiseToFuture(web_helpers.Notification.requestPermission());
  }

  void close() {
    _impl.close();
  }
}
