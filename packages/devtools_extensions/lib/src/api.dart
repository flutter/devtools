// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Supported events that can be sent and received over 'postMessage' between
/// DevTools and a DevTools extension running in an embedded iFrame.
enum DevToolsExtensionEventType {
  /// An event that a DevTools extension expects from DevTools to verify that
  /// the extension is ready for use.
  ping,

  /// An event that a DevTools extension will send back to DevTools after
  /// receiving a [ping] event.
  pong,

  /// Any unrecognized event that is not one of the above supported event types.
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
