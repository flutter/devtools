// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum NonProdFeatureLevel {
  beta,
  experiment,
}

// It is ok to have enum-like static only classes.
// ignore: avoid_classes_with_only_static_members
/// Flags to hide features under construction.
abstract class FeatureFlags {
  static void enableNonProdFeatures(NonProdFeatureLevel level) {
    if (level == NonProdFeatureLevel.experiment) {
      embeddedPerfetto = true;
      return;
    }

    memoryDiffing = true;
  }

  /// https://github.com/flutter/devtools/issues/3949
  static bool memoryDiffing = false;

  /// Flag to enable the embedded perfetto trace viewer.
  ///
  /// https://github.com/flutter/devtools/issues/4207.
  static bool embeddedPerfetto = false;
}
