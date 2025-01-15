// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/foundation.dart';

import '../../frame_analysis/frame_analysis_model.dart';

@immutable
class EnhanceTracingState {
  const EnhanceTracingState({
    required this.builds,
    required this.layouts,
    required this.paints,
  });

  final bool builds;
  final bool layouts;
  final bool paints;

  bool enhancedFor(FramePhaseType type) {
    switch (type) {
      case FramePhaseType.build:
        return builds;
      case FramePhaseType.layout:
        return layouts;
      case FramePhaseType.paint:
        return paints;
      default:
        return false;
    }
  }
}
