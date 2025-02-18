// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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

const _kMemoryDisconnectExperience = bool.fromEnvironment(
  'memory_disconnect_experience',
  defaultValue: true,
);

const _kNetworkDisconnectExperience = bool.fromEnvironment(
  'network_disconnect_experience',
  defaultValue: true,
);

// It is ok to have enum-like static only classes.
// ignore: avoid_classes_with_only_static_members
/// Flags to hide features under construction.
///
/// When adding a new feature flag, the developer is responsible for adding it
/// to the [_allFlags] map for debugging purposes.
abstract class FeatureFlags {
  /// Example usage of a flag for a beta feature.
  static bool myBetaFeature = enableBeta;

  /// Example usage of a flag for an experimental feature.
  static bool myExperimentalFeature = enableExperiments;

  /// Flag to enable widget rebuild stats ui.
  ///
  /// https://github.com/flutter/devtools/issues/4564.
  static bool widgetRebuildStats = true;

  /// Flag to enable viewing offline data on the memory screen when an app
  /// disconnects.
  ///
  /// https://github.com/flutter/devtools/issues/5606
  static const memoryDisconnectExperience = _kMemoryDisconnectExperience;

  /// Flag to enable save/load for the Memory screen.
  ///
  /// https://github.com/flutter/devtools/issues/8019
  static bool memorySaveLoad = enableExperiments;

  /// Flag to enable viewing offline data on the network screen when an app
  /// disconnects.
  ///
  /// https://github.com/flutter/devtools/issues/3806
  static const networkDisconnectExperience = _kNetworkDisconnectExperience;

  /// Flag to enable save/load for the Network screen.
  ///
  /// https://github.com/flutter/devtools/issues/4470
  static bool networkSaveLoad = true;

  /// Flag to enable the deep link validation tooling in DevTools, both for the
  /// DevTools screen and the standalone tool for IDE embedding.
  ///
  /// https://github.com/flutter/devtools/issues/6013
  static bool deepLinkValidation = true;

  /// Flag to enable ios checks in deep link validation.
  ///
  /// https://github.com/flutter/devtools/issues/7799
  static bool deepLinkIosCheck = true;

  /// Flag to enable DevTools extensions.
  ///
  /// TODO(https://github.com/flutter/devtools/issues/6443): remove this flag
  /// once extension support is added in g3.
  static bool devToolsExtensions = isExternalBuild;

  /// Flag to enable debugging via DAP.
  ///
  /// https://github.com/flutter/devtools/issues/6056
  static bool dapDebugging = enableExperiments;

  /// Flag to enable the new Inspector panel.
  ///
  /// https://github.com/flutter/devtools/issues/7854
  static bool inspectorV2 = true;

  /// Flag to enable the DevTools setting to opt-in to WASM.
  ///
  /// https://github.com/flutter/devtools/issues/7856
  static bool wasmOptInSetting = true;

  /// Flag to enable the Flutter Property Editor sidebar.
  ///
  /// https://github.com/flutter/devtools/issues/7854
  static bool propertyEditor = enableExperiments;

  /// Stores a map of all the feature flags for debugging purposes.
  ///
  /// When adding a new flag, you are responsible for adding it to this map as
  /// well.
  static final _allFlags = <String, bool>{
    'widgetRebuildStats': widgetRebuildStats,
    'memorySaveLoad': memorySaveLoad,
    'deepLinkIosCheck': deepLinkIosCheck,
    'dapDebugging': dapDebugging,
    'inspectorV2': inspectorV2,
    'wasmOptInSetting': wasmOptInSetting,
    'propertyEditor': propertyEditor,
  };

  /// A helper to print the status of all the feature flags.
  static void debugPrintFeatureFlags() {
    for (final entry in _allFlags.entries) {
      _log.config('${entry.key}: ${entry.value}');
    }
  }
}
