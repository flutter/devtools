// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:async';
import 'dart:html' as html;

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../api.dart';

part 'extension_manager.dart';

/// A manager that allows extensions to interact with DevTools or the DevTools
/// extensions framework.
///
/// A couple of use case examples include posting messages to DevTools or
/// registering an event handler from the extension.
ExtensionManager get extensionManager =>
    globals[ExtensionManager] as ExtensionManager;

/// A manager for interacting with the connected vm service, if present.
///
/// This manager provides sub-managers to interact with isolates, service
/// extensions, etc.
ServiceManager get serviceManager => globals[ServiceManager] as ServiceManager;

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
    _initGlobals();
    extensionManager._init(
      connectToVmService: widget.requiresRunningApplication,
    );
    for (final handler in widget.eventHandlers.entries) {
      extensionManager.registerEventHandler(handler.key, handler.value);
    }
  }

  void _initGlobals() {
    setGlobal(ExtensionManager, ExtensionManager());
    setGlobal(ServiceManager, ServiceManager());
    // TODO(kenz): pull the IDE theme from the url query params.
    setGlobal(IdeTheme, IdeTheme());
  }

  @override
  void dispose() {
    extensionManager._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      ),
      darkTheme: themeFor(
        isDarkTheme: true,
        ideTheme: ideTheme,
        theme: ThemeData(useMaterial3: true, colorScheme: darkColorScheme),
      ),
      home: Scaffold(
        body: widget.child,
      ),
    );
  }
}
