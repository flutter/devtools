// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../app.dart';

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

bool enableExperiments = _kEnableExperiments;

@visibleForTesting
bool enableBeta = _kEnableExperiments || !isExternalBuild;

// It is ok to have enum-like static only classes.
// ignore: avoid_classes_with_only_static_members
/// Flags to hide features under construction.
abstract class FeatureFlags {
  /// https://github.com/flutter/devtools/issues/3949
  static bool memoryDiffing = enableBeta;

  /// Flag to enable the embedded perfetto trace viewer.
  ///
  /// https://github.com/flutter/devtools/issues/4207.
  static bool embeddedPerfetto = enableExperiments;
}
