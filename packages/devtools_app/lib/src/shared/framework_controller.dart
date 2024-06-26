// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/shared.dart';

import 'globals.dart';

/// This controller is used by the connection to the DevTools server to receive
/// commands from the server, and to notify the server of DevTools state changes
/// (page changes and device connection status changes).
class FrameworkController {
  FrameworkController() {
    _init();
  }

  final _showPageIdController = StreamController<String>.broadcast();
  final _connectVmController = StreamController<ConnectVmEvent>.broadcast();
  final _connectedController = StreamController<String>.broadcast();
  final _disconnectedController = StreamController<void>.broadcast();
  final _pageChangeController = StreamController<PageChangeEvent>.broadcast();

  /// Show the indicated page.
  Stream<String> get onShowPageId => _showPageIdController.stream;

  /// Notify the controller of a request to show the page [pageId].
  void notifyShowPageId(String pageId) {
    _showPageIdController.add(pageId);
  }

  /// Tell DevTools to connect to the app at the given VM service protocol URI.
  Stream<ConnectVmEvent> get onConnectVmEvent => _connectVmController.stream;

  /// Notify the controller of a connect to VM event.
  void notifyConnectToVmEvent(Uri serviceProtocolUri, {bool notify = false}) {
    _connectVmController.add(
      ConnectVmEvent(
        serviceProtocolUri: serviceProtocolUri,
        notify: notify,
      ),
    );
  }

  /// Notifies when DevTools connects to a device.
  ///
  /// The returned URI value is the VM service protocol URI of the device
  /// connection.
  Stream<String> get onConnected => _connectedController.stream;

  /// Notifies when the current page changes.
  Stream<PageChangeEvent> get onPageChange => _pageChangeController.stream;

  /// Notify the controller that the current page has changed.
  void notifyPageChange(PageChangeEvent page) {
    _pageChangeController.add(page);
  }

  /// Notifies when a device disconnects from DevTools.
  Stream get onDisconnected => _disconnectedController.stream;

  void _init() {
    serviceConnection.serviceManager.connectedState.addListener(() {
      final connectionState =
          serviceConnection.serviceManager.connectedState.value;
      if (connectionState.connected) {
        _connectedController.add(serviceConnection.serviceManager.serviceUri!);
      } else {
        _disconnectedController.add(null);
      }
    });
  }
}

class ConnectVmEvent {
  ConnectVmEvent({required this.serviceProtocolUri, this.notify = false});

  final Uri serviceProtocolUri;
  final bool notify;
}

class PageChangeEvent {
  PageChangeEvent(this.id, this.embedMode);

  final String id;
  final EmbedMode embedMode;
}
