// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file contain higher level utils, i.e. utils that depend on
// other libraries in this package.
// Utils, that do not have dependencies, should go to primitives/utils.dart.

import 'dart:async';

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

final _log = Logger('lib/src/shared/utils');

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`.
Future<void> copyToClipboard(
  String data,
  String? successMessage,
) async {
  await Clipboard.setData(
    ClipboardData(
      text: data,
    ),
  );

  if (successMessage != null) notificationService.push(successMessage);
}

/// Logging to debug console only in debug runs.
void debugLogger(String message) {
  assert(
    () {
      _log.info(message);
      return true;
    }(),
  );
}

double scaleByFontFactor(double original) {
  return (original * ideTheme.fontSizeFactor).roundToDouble();
}

bool isDense() {
  return preferences.denseModeEnabled.value || isEmbedded();
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

List<_ConnectionDescription> generateDeviceDescription(
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

  _ConnectionDescription? vmServiceConnection;
  if (includeVmServiceConnection && serviceManager.service != null) {
    final description = serviceManager.service!.connectedUri.toString();
    vmServiceConnection = _ConnectionDescription(
      title: 'VM Service Connection',
      description: description,
      actions: [CopyToClipboardControl(dataProvider: () => description)],
    );
  }

  return [
    _ConnectionDescription(title: 'CPU / OS', description: vm.deviceDisplay),
    _ConnectionDescription(title: 'Dart Version', description: version),
    if (flutterVersion != null) ...{
      _ConnectionDescription(
        title: 'Flutter Version',
        description: '${flutterVersion.version} / ${flutterVersion.channel}',
      ),
      _ConnectionDescription(
        title: 'Framework / Engine',
        description: '${flutterVersion.frameworkRevision} / '
            '${flutterVersion.engineRevision}',
      ),
    },
    _ConnectionDescription(
      title: 'Connected app type',
      description: connectedApp.display,
    ),
    if (vmServiceConnection != null) vmServiceConnection,
  ];
}

/// This method should be public, because it is used by g3 specific code.
List<String> issueLinkDetails() {
  final issueDescriptionItems = [
    '<-- Please describe your problem here. Be sure to include repro steps. -->',
    '___', // This will create a separator in the rendered markdown.
    '**DevTools version**: ${devtools.version}',
  ];
  final vm = serviceManager.vm;
  final connectedApp = serviceManager.connectedApp;
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

typedef _ProvidedControllerCallback<T> = void Function(T);

/// Mixin that provides a [controller] from package:provider for a State class.
///
/// [initController] must be called from [State.didChangeDependencies]. If
/// [initController] returns false, return early from [didChangeDependencies] to
/// avoid calling any initialization code that should only be called once for a
/// controller. See [initController] documentation below for more details.
mixin ProvidedControllerMixin<T, V extends StatefulWidget> on State<V> {
  T get controller => _controller!;

  T? _controller;

  final _callWhenReady = <_ProvidedControllerCallback>[];

  /// Calls the provided [callback] once [_controller] has been initialized.
  ///
  /// The [callback] will be called immediately if [_controller] has already
  /// been initialized.
  void callWhenControllerReady(_ProvidedControllerCallback callback) {
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

class _ConnectionDescription {
  _ConnectionDescription({
    required this.title,
    required this.description,
    this.actions = const <Widget>[],
  });

  final String title;

  final String description;

  final List<Widget> actions;
}
