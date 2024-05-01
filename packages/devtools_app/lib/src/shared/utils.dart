// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file contain higher level utils, i.e. utils that depend on
// other libraries in this package.
// Utils, that do not have dependencies, should go to primitives/utils.dart.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools;
import 'common_widgets.dart';
import 'connected_app.dart';
import 'globals.dart';
import 'primitives/simple_items.dart';

final _log = Logger('lib/src/shared/utils');

/// Logging to debug console only in debug runs.
void debugLogger(String message) {
  assert(
    () {
      _log.info(message);
      return true;
    }(),
  );
}

bool isEmbedded() => ideTheme.embed;

extension VmExtension on VM {
  List<IsolateRef> isolatesForDevToolsMode() {
    final vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;
    final vmIsolates = isolates ?? <IsolateRef>[];
    return [
      ...vmIsolates,
      if (vmDeveloperModeEnabled || vmIsolates.isEmpty)
        ...systemIsolates ?? <IsolateRef>[],
    ];
  }

  String get deviceDisplay {
    return [
      '$targetCPU',
      if (architectureBits != null && architectureBits != -1)
        '($architectureBits bit)',
      operatingSystem,
    ].join(' ');
  }
}

List<ConnectionDescription> generateDeviceDescription(
  VM vm,
  ConnectedApp connectedApp, {
  bool includeVmServiceConnection = true,
}) {
  var version = vm.version!;
  // Convert '2.9.0-13.0.dev (dev) (Fri May ... +0200) on "macos_x64"' to
  // '2.9.0-13.0.dev'.
  if (version.contains(' ')) {
    version = version.substring(0, version.indexOf(' '));
  }

  final flutterVersion = connectedApp.flutterVersionNow;

  ConnectionDescription? vmServiceConnection;
  if (includeVmServiceConnection &&
      serviceConnection.serviceManager.service != null) {
    final description = serviceConnection.serviceManager.serviceUri!;
    vmServiceConnection = ConnectionDescription(
      title: 'VM Service Connection',
      description: description,
      actions: [
        CopyToClipboardControl(
          dataProvider: () => description,
        ),
      ],
    );
  }

  return [
    ConnectionDescription(title: 'CPU / OS', description: vm.deviceDisplay),
    ConnectionDescription(
      title: 'Connected app type',
      description: connectedApp.display,
    ),
    if (vmServiceConnection != null) vmServiceConnection,
    ConnectionDescription(title: 'Dart Version', description: version),
    if (flutterVersion != null && !flutterVersion.unknown) ...{
      ConnectionDescription(
        title: 'Flutter Version',
        description: '${flutterVersion.version} / ${flutterVersion.channel}',
      ),
      ConnectionDescription(
        title: 'Framework / Engine',
        description: '${flutterVersion.frameworkRevision} / '
            '${flutterVersion.engineRevision}',
      ),
    },
  ];
}

/// This method should be public, because it is used by g3 specific code.
List<String> issueLinkDetails() {
  final ide = ideFromUrl();
  final issueDescriptionItems = [
    '<-- Please describe your problem here. Be sure to include repro steps. -->',
    '___', // This will create a separator in the rendered markdown.
    '**DevTools version**: ${devtools.version}',
    if (ide != null) '**IDE**: $ide',
  ];
  final vm = serviceConnection.serviceManager.vm;
  final connectedApp = serviceConnection.serviceManager.connectedApp;
  if (vm != null && connectedApp != null) {
    final descriptionEntries = generateDeviceDescription(
      vm,
      connectedApp,
      includeVmServiceConnection: false,
    );
    final deviceDescription = descriptionEntries
        .map((entry) => '${entry.title}: ${entry.description}');
    issueDescriptionItems.addAll([
      '**Connected Device**:',
      ...deviceDescription,
    ]);
  }
  return issueDescriptionItems;
}

typedef ProvidedControllerCallback<T> = void Function(T);

/// Mixin that provides a [controller] from package:provider for a State class.
///
/// [initController] must be called from [State.didChangeDependencies]. If
/// [initController] returns false, return early from [didChangeDependencies] to
/// avoid calling any initialization code that should only be called once for a
/// controller. See [initController] documentation below for more details.
mixin ProvidedControllerMixin<T, V extends StatefulWidget> on State<V> {
  T get controller => _controller!;

  T? _controller;

  final _callWhenReady = <ProvidedControllerCallback>[];

  /// Calls the provided [callback] once [_controller] has been initialized.
  ///
  /// The [callback] will be called immediately if [_controller] has already
  /// been initialized.
  void callWhenControllerReady(ProvidedControllerCallback callback) {
    if (_controller != null) {
      callback(_controller!);
    } else {
      _callWhenReady.add(callback);
    }
  }

  /// Initializes [_controller] from package:provider.
  ///
  /// This method should be called in [didChangeDependencies]. Returns whether
  /// or not a new controller was provided upon subsequent calls to
  /// [initController].
  ///
  /// This method will commonly be used to return early from
  /// [didChangeDependencies] when initialization code should not be run again
  /// if the provided controller has not changed.
  ///
  /// E.g. `if (!initController()) return;`
  bool initController() {
    final newController = Provider.of<T>(context);
    if (newController == _controller) return false;
    final firstInitialization = _controller == null;
    _controller = newController;
    if (firstInitialization) {
      for (final callback in _callWhenReady) {
        callback(_controller!);
      }
      _callWhenReady.clear();
    }
    return true;
  }
}

class ConnectionDescription {
  ConnectionDescription({
    required this.title,
    required this.description,
    this.actions = const <Widget>[],
  });

  final String title;

  final String description;

  final List<Widget> actions;
}

String? ideFromUrl() {
  return lookupFromQueryParams('ide');
}

String? lookupFromQueryParams(String key) {
  final queryParameters = loadQueryParams();
  return queryParameters[key];
}

const _google3PathSegment = 'google3';

bool isGoogle3Path(List<String> pathParts) =>
    pathParts.contains(_google3PathSegment);

List<String> stripGoogle3(List<String> pathParts) {
  final google3Index = pathParts.lastIndexOf(_google3PathSegment);
  if (google3Index != -1 && google3Index + 1 < pathParts.length) {
    return pathParts.sublist(google3Index + 1);
  }
  return pathParts;
}

/// An extension on [KeyEvent] to make it simpler to determine if it is a key
/// down event.
extension IsKeyType on KeyEvent {
  bool get isKeyDownOrRepeat => this is KeyDownEvent || this is KeyRepeatEvent;
}

/// A helper class for [Timer] functionality, where the callbacks are debounced.
class DebounceTimer {
  /// A periodic timer that ensures [callback] is only called at most once
  /// per [duration].
  ///
  /// [callback] is triggered once immediately, and then every [duration] the
  /// timer checks to see if the previous [callback] call has finished running.
  /// If it has finished, then then next call to [callback] will begin.
  DebounceTimer.periodic(
    Duration duration,
    Future<void> Function() callback,
  ) : _callback = callback {
    // Start running the first call to the callback.
    _runCallback();

    // Start periodic timer so that the callback will be periodically triggered
    // after the first callback.
    _timer = Timer.periodic(duration, (_) => _runCallback());
  }

  void _runCallback() async {
    // If the previous callback is still running, then don't trigger another
    // callback. (debounce)
    if (_isRunning) {
      return;
    }

    try {
      _isRunning = true;
      await _callback();
    } finally {
      _isRunning = false;
    }
  }

  late final Timer _timer;
  final Future<void> Function() _callback;
  bool _isRunning = false;

  void cancel() {
    _timer.cancel();
  }

  bool get isCancelled => !_timer.isActive;

  void dispose() {
    cancel();
  }
}

/// Current mode of DevTools.
DevToolsMode get devToolsMode {
  return offlineDataController.showingOfflineData.value
      ? DevToolsMode.offlineData
      : serviceConnection.serviceManager.hasConnection
          ? DevToolsMode.connected
          : DevToolsMode.disconnected;
}
