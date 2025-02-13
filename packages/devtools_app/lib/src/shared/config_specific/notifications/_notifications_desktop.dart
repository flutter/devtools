// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

class Notification {
  Notification(String title, {String? body}) {
    throw Exception('unsupported platform');
  }

  static Future<String> requestPermission() {
    throw Exception('unsupported platform');
  }

  void close() {
    throw Exception('unsupported platform');
  }
}
