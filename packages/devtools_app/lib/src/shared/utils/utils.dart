// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// This file contain higher level utils, i.e. utils that depend on
// other libraries in this package.
// Utils, that do not have dependencies, should go to primitives/utils.dart.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../../../devtools.dart' as devtools;
import '../../service/connected_app/connected_app.dart';
import '../globals.dart';
import '../primitives/query_parameters.dart';
import '../primitives/utils.dart';
import '../ui/common_widgets.dart';

final _log = Logger('lib/src/shared/utils');

/// Logging to debug console only in debug runs.
void debugLogger(String message) {
  assert(() {
    _log.info(message);
    return true;
  }());
}

/// Whether DevTools is using a dark theme.
///
/// When DevTools is in embedded mode, we first check if the [ideTheme] has
/// specified a light or dark theme, and if it has we use this value. This is
/// safe to do because the user cannot access the dark theme DevTools setting
/// when in embedded mode, which is intentional so that the embedded DevTools
/// matches the theme of its surrounding window (the IDE).
///
/// When DevTools is not embedded, we use the user preference to determine
/// whether DevTools is using a light or dark theme.
///
/// This utility method should be used in favor of checking
/// [preferences.darkModeTheme.value] so that the embedded case is always
/// handled properly.
bool isDarkThemeEnabled() {
  return isEmbedded() && ideTheme.ideSpecifiedTheme
      ? ideTheme.isDarkMode
      : preferences.darkModeEnabled.value;
}

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
      actions: [CopyToClipboardControl(dataProvider: () => description)],
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
        description:
            '${flutterVersion.frameworkRevision} / '
            '${flutterVersion.engineRevision}',
      ),
    },
  ];
}

/// This method should be public, because it is used by g3 specific code.
List<String> issueLinkDetails() {
  final ide = DevToolsQueryParams.load().ide;
  final issueDescriptionItems = [
    '<-- Please describe your problem here. Be sure to include repro steps. -->',
    '___', // This will create a separator in the rendered markdown.
    '**DevTools version**: $devToolsVersion',
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
    final deviceDescription = descriptionEntries.map(
      (entry) => '${entry.title}: ${entry.description}',
    );
    issueDescriptionItems.addAll([
      '**Connected Device**:',
      ...deviceDescription,
    ]);
  }
  return issueDescriptionItems;
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

typedef DebounceCancelledCallback = bool Function();

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
    Future<void> Function({DebounceCancelledCallback? cancelledCallback})
    callback,
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

    if (isCancelled) return;

    try {
      _isRunning = true;
      await _callback(cancelledCallback: () => isCancelled);
    } finally {
      _isRunning = false;
    }
  }

  Timer? _timer;
  final Future<void> Function({DebounceCancelledCallback? cancelledCallback})
  _callback;
  bool _isRunning = false;
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
    _timer?.cancel();
  }

  bool get isCancelled => _isCancelled || (_timer != null && !_timer!.isActive);

  void dispose() {
    cancel();
  }
}

Future<void> launchUrlWithErrorHandling(String url) async {
  await launchUrl(
    url,
    onError: () => notificationService.push('Unable to open $url.'),
  );
}

/// A worker that will run [callback] in groups of [chunkSize], when [doWork] is called.
///
/// [progressCallback] will be called with 0.0 progress when starting the work and any
/// time a chunk finishes running, with a value that represents the proportion of
/// indices that have been completed so far.
///
/// This class may be helpful when sets of work need to be done over a list, while
/// avoiding blocking the UI thread.
class InterruptableChunkWorker {
  InterruptableChunkWorker({
    int chunkSize = _defaultChunkSize,
    required this.callback,
    required this.progressCallback,
  }) : _chunkSize = chunkSize;

  static const _defaultChunkSize = 50;

  final int _chunkSize;
  int _workId = 0;
  bool _disposed = false;

  void Function(int) callback;
  void Function(double progress) progressCallback;

  /// Start doing the chunked work.
  ///
  /// [callback] will be called on every index from 0...[length-1], inclusive,
  /// in chunks of [_chunkSize]
  ///
  /// If [doWork] is called again, then [callback] will no longer be called
  /// on any remaining indices from previous [doWork] calls.
  ///
  Future<bool> doWork(int length) {
    final completer = Completer<bool>();
    final localWorkId = ++_workId;

    Future<void> doChunkWork(int chunkStartingIndex) async {
      if (_disposed) {
        return completer.complete(false);
      }
      if (chunkStartingIndex >= length) {
        return completer.complete(true);
      }

      final chunkUpperIndexLimit = min(length, chunkStartingIndex + _chunkSize);

      for (
        int indexIterator = chunkStartingIndex;
        indexIterator < chunkUpperIndexLimit;
        indexIterator++
      ) {
        // If our localWorkId is no longer active, then do not continue working
        if (localWorkId != _workId) return completer.complete(false);
        callback(indexIterator);
      }

      progressCallback(chunkUpperIndexLimit / length);
      await delayToReleaseUiThread();
      await doChunkWork(chunkStartingIndex + _chunkSize);
    }

    if (length <= 0) {
      return Future.value(true);
    }

    progressCallback(0.0);
    doChunkWork(0);

    return completer.future;
  }

  void dispose() {
    _disposed = true;
  }
}

String get devToolsVersion => devtools.version;
