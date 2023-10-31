// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' hide Event;
import 'package:web/helpers.dart' hide Text;

import '../api/api.dart';
import '../api/model.dart';
import '_simulated_devtools_environment/_simulated_devtools_environment.dart';

part 'extension_manager.dart';

/// If true, a simulated DevTools environment will be wrapped around the
/// extension (see [SimulatedDevToolsWrapper]).
///
/// By default, the constant is false.
/// To enable it, pass the compilation flag
/// `--dart-define=use_simulated_environment=true`.
///
/// To enable the flag in debug configuration of VSCode, add value:
///   "args": [
///     "--dart-define=use_simulated_environment=true"
///   ]
const bool _simulatedEnvironmentEnabled =
    bool.fromEnvironment('use_simulated_environment');

bool get _useSimulatedEnvironment =>
    !kReleaseMode && _simulatedEnvironmentEnabled;

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

class _DevToolsExtensionState extends State<DevToolsExtension>
    with AutoDisposeMixin {
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

    addAutoDisposeListener(extensionManager.darkThemeEnabled);
  }

  void _initGlobals() {
    setGlobal(ExtensionManager, ExtensionManager());
    setGlobal(ServiceManager, ServiceManager());
    // TODO(kenz): pull the IDE theme from the url query params.
    setGlobal(IdeTheme, IdeTheme());
  }

  void _shutdown() {
    (globals[ExtensionManager] as ExtensionManager?)?._dispose();
    removeGlobal(ExtensionManager);
    removeGlobal(ServiceManager);
    removeGlobal(IdeTheme);
  }

  @override
  void dispose() {
    // TODO(https://github.com/flutter/flutter/issues/10437): dispose is never
    // called on hot restart, so these resources leak for local development.
    _shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _ConnectionAwareWrapper(
      requiresRunningApplication: widget.requiresRunningApplication,
      child: widget.child,
    );
    return MaterialApp(
      themeMode: extensionManager.darkThemeEnabled.value
          ? ThemeMode.dark
          : ThemeMode.light,
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
        body: _useSimulatedEnvironment
            ? SimulatedDevToolsWrapper(
                requiresRunningApplication: widget.requiresRunningApplication,
                child: child,
              )
            : child,
      ),
    );
  }
}

class _ConnectionAwareWrapper extends StatelessWidget {
  const _ConnectionAwareWrapper({
    required this.child,
    required this.requiresRunningApplication,
  });

  final bool requiresRunningApplication;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: serviceManager.connectedState,
      builder: (context, connectedState, _) {
        if (requiresRunningApplication && !connectedState.connected) {
          return const Center(
            child: Text('Please connect an app to use this DevTools Extension'),
          );
        }
        return child;
      },
    );
  }
}
