// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../../api.dart';
import 'connected_app_manager.dart';

part 'extension_manager.dart';

/// A manager that allows extensions to interact with DevTools or the DevTools
/// extensions framework.
///
/// A couple of use case examples include posting messages to DevTools or
/// registering an event handler from the extension.
ExtensionManager get extensionManager => _extensionManager;
late final ExtensionManager _extensionManager;

/// A wrapper widget that initializes the [extensionManager] and establishes a
/// connection with DevTools for this extension to interact over.
class DevToolsExtension extends StatefulWidget {
  const DevToolsExtension({
    super.key,
    required this.child,
    this.eventHandlers = const {},
    this.requiresRunningApplication = true,
  });

  /// The root of the extension Flutter web app that is wrapped by this
  /// [DevToolsExtension] wrapper.
  final Widget child;

  /// Event handlers registered by the extension so that it can respond to
  /// DevTools events.
  final Map<DevToolsExtensionEventType, ExtensionEventHandler> eventHandlers;

  /// Whether this extension requires a running application to use.
  final bool requiresRunningApplication;

  @override
  State<DevToolsExtension> createState() => _DevToolsExtensionState();
}

class _DevToolsExtensionState extends State<DevToolsExtension> {
  @override
  void initState() {
    super.initState();
    _extensionManager = ExtensionManager()
      .._init(connectToVmService: widget.requiresRunningApplication);
    for (final handler in widget.eventHandlers.entries) {
      _extensionManager.registerEventHandler(handler.key, handler.value);
    }
  }

  @override
  void dispose() {
    _extensionManager._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
