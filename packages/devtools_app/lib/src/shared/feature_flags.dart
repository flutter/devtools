// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum FeatureLevel {
  prodOnly(0),
  beta(1),
  experiments(2);

  const FeatureLevel(this.value);
  final num value;
}

// It is ok to have enum-like static only classes.
// ignore: avoid_classes_with_only_static_members
/// Flags to hide features under construction.
abstract class FeatureFlags {
  static void setFeatureLevel(FeatureLevel level) {
    if (level == FeatureLevel.prodOnly) return;

    if (level.value >= FeatureLevel.beta.value) {
      memoryDiffing = true;
    }

    if (level.value >= FeatureLevel.experiments.value) {
      embeddedPerfetto = true;
    }
  }

  /// https://github.com/flutter/devtools/issues/3949
  static bool memoryDiffing = false;

  /// Flag to enable the embedded perfetto trace viewer.
  ///
  /// https://github.com/flutter/devtools/issues/4207.
  static bool embeddedPerfetto = false;
}
