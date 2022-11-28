// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../shared/globals.dart';

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
const bool _kEnableExperiments = bool.fromEnvironment('enable_experiments');

@visibleForTesting
bool enableExperiments = _kEnableExperiments;
void setExperimentsEnabled() => enableExperiments = true;

@visibleForTesting
bool get enableBeta => enableExperiments || !isExternalBuild;

// It is ok to have enum-like static only classes.
// ignore: avoid_classes_with_only_static_members
/// Flags to hide features under construction.
///
/// When adding a new feature flag, the developer is respsonsible for adding it
/// to the [_allFlags] map for debugging purposes.
abstract class FeatureFlags {
  /// Example usage of a flag for a beta feature.
  static bool myBetaFeature = enableBeta;

  /// Example usage of a flag for an experimental feature.
  static bool myExperimentalFeature = enableExperiments;

  /// Flag to enable the embedded perfetto trace viewer.
  ///
  /// https://github.com/flutter/devtools/issues/4207.
  static bool embeddedPerfetto = enableExperiments;

  /// Flag to enable widget rebuild stats ui.
  ///
  /// https://github.com/flutter/devtools/issues/4564.
  static bool widgetRebuildstats = enableExperiments;

  /// Stores a map of all the feature flags for debugging purposes.
  ///
  /// When adding a new flag, you are responsible for adding it to this map as
  /// well.
  static final _allFlags = <String, bool>{
    'embeddedPerfetto': embeddedPerfetto,
    'widgetRebuildStats': widgetRebuildstats,
  };

  /// A helper to print the status of all the feature flags.
  static void debugPrintFeatureFlags() {
    for (final entry in _allFlags.entries) {
      print('${entry.key}: ${entry.value}');
    }
  }
}
