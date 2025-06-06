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

const _kNetworkDisconnectExperience = bool.fromEnvironment(
  'network_disconnect_experience',
  defaultValue: true,
);

/// A namespace for feature flags, which set the visibility of features under
/// active development.
///
/// When adding a new feature flag, the developer is responsible for adding it
/// to the [_allFlags] map for debugging purposes.
extension FeatureFlags on Never {
  /// Flag to enable the DevTools memory observer, which attempts to help users
  /// avoid OOM crashes.
  ///
  /// https://github.com/flutter/devtools/issues/7002
  static bool memoryObserver = true;

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

  /// Flag to enable refactors in the Flutter Property Editor sidebar.
  ///
  /// https://github.com/flutter/devtools/issues/9214
  static bool propertyEditorRefactors = true;

  /// Stores a map of all the feature flags for debugging purposes.
  ///
  /// When adding a new flag, you are responsible for adding it to this map as
  /// well.
  static final _allFlags = <String, bool>{
    'memoryObserver': memoryObserver,
    'memorySaveLoad': memorySaveLoad,
    'networkDisconnectExperience': networkDisconnectExperience,
    'networkSaveLoad': networkSaveLoad,
    'dapDebugging': dapDebugging,
    'inspectorV2': inspectorV2,
    'wasmOptInSetting': wasmOptInSetting,
    'propertyEditorRefactors': propertyEditorRefactors,
  };

  /// A helper to print the status of all the feature flags.
  static void debugPrintFeatureFlags() {
    for (final entry in _allFlags.entries) {
      _log.config('${entry.key}: ${entry.value}');
    }
  }
}
