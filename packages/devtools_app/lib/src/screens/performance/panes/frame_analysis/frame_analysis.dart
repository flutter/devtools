// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../controls/enhance_tracing/enhance_tracing_controller.dart';
import 'frame_analysis_model.dart';
import 'frame_hints.dart';
import 'frame_time_visualizer.dart';

class FlutterFrameAnalysisView extends StatelessWidget {
  const FlutterFrameAnalysisView({
    Key? key,
    required this.frameAnalysis,
    required this.enhanceTracingController,
  }) : super(key: key);

  final FrameAnalysis? frameAnalysis;

  final EnhanceTracingController enhanceTracingController;

  @override
  Widget build(BuildContext context) {
    final frameAnalysis = this.frameAnalysis;
    if (frameAnalysis == null) {
      return const Center(
        child: Text('No analysis data available for this frame.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrameHints(
            frameAnalysis: frameAnalysis,
            enhanceTracingController: enhanceTracingController,
          ),
          const PaddedDivider(
            padding: EdgeInsets.only(
              top: denseSpacing,
              bottom: denseSpacing,
            ),
          ),
          Expanded(
            child: FrameTimeVisualizer(frameAnalysis: frameAnalysis),
          ),
        ],
      ),
    );
  }
}
