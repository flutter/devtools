// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// If true, features under construction will be enabled.
///
/// By default, the constant is false.
/// To enable it, pass the compilation flag
/// `--dart-define=enable_experiments=true`.
///
/// To enable the flag in debug configuration of VSCode, add value:
///   "args": [
///     "--dart-define=enable_experiments=true"
///   ]

bool _kEnableExperiments =
    const bool.fromEnvironment('enable_experiments') || !kReleaseMode;

/// Whether this DevTools build is external.
const bool isExternalBuild = true;

/// If true, features, ready for beta testing, will be on.
///
/// Always true when [_kEnableExperiments] is true.
/// See [_kEnableExperiments] documentation  for usage.
const bool _kEnableBeta = !isExternalBuild;

// It is ok to have enum-like static only classes.
// ignore: avoid_classes_with_only_static_members
/// Flags to hide features under construction.
abstract class FeatureFlags {
  /// https://github.com/flutter/devtools/issues/3949
  static bool memoryDiffing = _kEnableBeta;

  /// Flag to enable the embedded perfetto trace viewer.
  ///
  /// https://github.com/flutter/devtools/issues/4207.
  static bool embeddedPerfetto = _kEnableExperiments;
}
