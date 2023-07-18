// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum DevToolsExtensionEventType {
  ping,
  pong,
  unknown;

  static DevToolsExtensionEventType from(String name) {
    for (final event in DevToolsExtensionEventType.values) {
      if (event.name == name) {
        return event;
      }
    }
    return unknown;
  }
}
