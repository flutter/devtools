// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/service.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'globals.dart';

final _log = Logger('lib/src/shared/features_flags');

@visibleForTesting
bool get enableExperiments =>
    _experimentsEnabledByEnvironment || _experimentsEnabledFromMain;

/// If true, features under construction will be enabled for release build.
///
/// By default, the constant is false.
/// To enable it, pass the compilation flag
/// `--dart-define=enable_experiments=true`.
///
/// To enable the flag in debug configuration of VSCode, add value:
///   "args": [
///     "--dart-define=enable_experiments=true"
///   ]
const _experimentsEnabledByEnvironment = bool.fromEnvironment(
  'enable_experiments',
);

bool _experimentsEnabledFromMain = false;

void setEnableExperiments() {
  _experimentsEnabledFromMain = true;
}

@visibleForTesting
bool get enableBeta => enableExperiments || !isExternalBuild;

/// A namespace for feature flags, which set the visibility of features under
/// active development.
///
/// When adding a new feature flag, the developer is responsible for adding it
/// to the [_booleanFlags] or [_flutterChannelFlags] map for debugging
/// purposes.
extension FeatureFlags on Never {
  /// Flag to enable save/load for the Memory screen.
  ///
  /// https://github.com/flutter/devtools/issues/8019
  static final memorySaveLoad = BooleanFeatureFlag(
    name: 'memorySaveLoad',
    enabled: enableExperiments,
  );

  /// Flag to enable save/load for the Network screen.
  ///
  /// https://github.com/flutter/devtools/issues/4470
  static final networkSaveLoad = BooleanFeatureFlag(
    name: 'networkSaveLoad',
    enabled: true,
  );

  /// Flag to enable DevTools extensions.
  ///
  /// TODO(https://github.com/flutter/devtools/issues/6443): remove this flag
  /// once extension support is added in g3.
  static final devToolsExtensions = BooleanFeatureFlag(
    name: 'devToolsExtensions',
    enabled: isExternalBuild,
  );

  /// Flag to enable debugging via DAP.
  ///
  /// https://github.com/flutter/devtools/issues/6056
  static final dapDebugging = BooleanFeatureFlag(
    name: 'dapDebugging',
    enabled: enableExperiments,
  );

  /// Flag to enable the new Inspector panel.
  ///
  /// https://github.com/flutter/devtools/issues/7854
  static final inspectorV2 = BooleanFeatureFlag(
    name: 'inspectorV2',
    enabled: true,
  );

  /// A set of all the boolean feature flags for debugging purposes.
  ///
  /// When adding a new boolean flag, you are responsible for adding it to this
  /// map as well.
  static final _booleanFlags = <BooleanFeatureFlag>{
    memorySaveLoad,
    networkSaveLoad,
    devToolsExtensions,
    dapDebugging,
    inspectorV2
  };

  /// A set of all the Flutter channel feature flags for debugging purposes.
  ///
  /// When adding a new Flutter channel flag, you are responsible for adding it
  /// to this map as well.
  static final _flutterChannelFlags = <FlutterChannelFeatureFlag>{};

  /// A helper to print the status of all the feature flags.
  static void debugPrintFeatureFlags({ConnectedApp? connectedApp}) {
    for (final entry in _booleanFlags) {
      _log.config(entry.toString());
    }

    for (final entry in _flutterChannelFlags) {
      var logLine = entry.toString();
      if (connectedApp != null) {
        logLine += '(enabled: ${entry.isEnabled(connectedApp)})';
      }
      _log.config(logLine);
    }
  }
}

/// A simple feature flag that is enabled or disabled by a boolean value.
class BooleanFeatureFlag {
  BooleanFeatureFlag({required this.name, required bool enabled})
    : _enabled = enabled;

  /// The name of the feature.
  final String name;

  bool _enabled;

  /// Whether the feature is enabled.
  bool get isEnabled => _enabled;

  @override
  String toString() => '$name: $isEnabled';

  @visibleForTesting
  void setEnabledForTests(bool enabled) {
    _enabled = enabled;
  }
}

/// A feature flag that is enabled based on the Flutter channel of the
/// connected application.
///
/// This flag will be enabled if the connected app's Flutter channel is less
/// than or equal to [flutterChannel]. For example, if [flutterChannel] is
/// [FlutterChannel.beta], this flag will be enabled for apps on the 'beta' and
/// 'dev' channels, but not for apps on the 'stable' channel.
///
/// TODO(https://github.com/flutter/devtools/issues/9439): Restrict features
/// based on the user's Dart version instead of Flutter version to allow for
/// shared experiments across Dart and Flutter.
class FlutterChannelFeatureFlag {
  const FlutterChannelFeatureFlag({
    required this.name,
    required this.flutterChannel,
    required bool enabledForDartApps,
    required bool enabledForFlutterAppsFallback,
  }) : _enabledForDartApps = enabledForDartApps,
       _enabledForFlutterAppsFallback = enabledForFlutterAppsFallback;

  /// The name of the feature.
  final String name;

  /// The maximum Flutter channel that this feature is enabled for.
  final FlutterChannel flutterChannel;

  /// Whether the feature is enabled when the connected app is a pure Dart app.
  final bool _enabledForDartApps;

  /// Whether the feature is enabled when the connected app is a Flutter app,
  /// but we cannot determine the Flutter channel.
  final bool _enabledForFlutterAppsFallback;

  /// Returns whether the feature is enabled based on the [connectedApp]'s
  /// Flutter version.
  bool isEnabled(ConnectedApp connectedApp) {
    final isFlutterApp = connectedApp.isFlutterAppNow ?? false;
    if (!isFlutterApp) {
      return _enabledForDartApps;
    }
    final flutterVersion = connectedApp.flutterVersionNow?.version;
    if (flutterVersion == null) return _enabledForFlutterAppsFallback;

    final currentChannel = FlutterVersion.identifyChannel(
      flutterVersion,
      channelStr: connectedApp.flutterVersionNow?.channel,
    );
    if (currentChannel == null) return _enabledForFlutterAppsFallback;

    return currentChannel <= flutterChannel;
  }

  @override
  String toString() => '$name: <=${flutterChannel.name}';
}
