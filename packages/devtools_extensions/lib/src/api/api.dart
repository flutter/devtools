// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart';

/// Supported events that can be sent and received over 'postMessage' between
/// DevTools and a DevTools extension running in an embedded iFrame.
enum DevToolsExtensionEventType {
  /// An event that a DevTools extension expects from DevTools to verify that
  /// the extension is ready for use.
  ping,

  /// An event that a DevTools extension will send back to DevTools after
  /// receiving a [ping] event.
  pong,

  /// An event that DevTools will send to an extension to notify of the
  /// connected vm service uri.
  vmServiceConnection,

  /// An event that an extension will send to DevTools asking DevTools to post
  /// a notification to the DevTools global [notificationService].
  showNotification,

  /// An event that an extension will send to DevTools asking DevTools to post
  /// a banner message to the extension's screen using the global
  /// [bannerMessages].
  showBannerMessage,

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

/// Interface that a DevTools extension host should implement.
///
/// This interface is implemented by DevTools itself as well as by a simulated
/// DevTools environment for simplifying extension development.
abstract interface class DevToolsExtensionHostInterface {
  /// This method should send a [DevToolsExtensionEventType.ping] event to the
  /// DevTools extension to check that it is ready.
  void ping();

  /// This method should send a [DevToolsExtensionEventType.vmServiceConnection]
  /// event to the extension to notify it of the vm service uri it should
  /// establish a connection to.
  void vmServiceConnectionChanged({required String? uri});

  /// Handles events sent by the extension.
  ///
  /// If an unknown event is received, this handler should call [onUnknownEvent]
  /// if non-null.
  void onEventReceived(
    DevToolsExtensionEvent event, {
    void Function()? onUnknownEvent,
  });
}
