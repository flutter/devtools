// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/theme.dart';
import '../../../../ui/colors.dart';
import '../../../../ui/utils.dart';
import '../../performance_model.dart';
import '../controls/enhance_tracing/enhance_tracing_controller.dart';
import 'frame_hints.dart';

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
          // TODO(kenz): handle missing timeline events.
          Expanded(
            child: FrameTimeVisualizer(frameAnalysis: frameAnalysis),
          ),
        ],
      ),
    );
  }
}

class FrameTimeVisualizer extends StatefulWidget {
  const FrameTimeVisualizer({
    Key? key,
    required this.frameAnalysis,
  }) : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  State<FrameTimeVisualizer> createState() => _FrameTimeVisualizerState();
}

class _FrameTimeVisualizerState extends State<FrameTimeVisualizer> {
  late FrameAnalysis frameAnalysis;

  @override
  void initState() {
    super.initState();
    frameAnalysis = widget.frameAnalysis;
    frameAnalysis.selectFramePhase(frameAnalysis.longestUiPhase);
  }

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): calculate ratios to use as flex values. This will be a bit
    // tricky because sometimes the Build event(s) are children of Layout.
    // final buildTimeRatio = widget.frameAnalysis.buildTimeRatio();
    // final layoutTimeRatio = widget.frameAnalysis.layoutTimeRatio();
    // final paintTimeRatio = widget.frameAnalysis.paintTimeRatio();
    return ValueListenableBuilder<FramePhase?>(
      valueListenable: frameAnalysis.selectedPhase,
      builder: (context, selectedPhase, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UI phases:'),
            const SizedBox(height: denseSpacing),
            Row(
              children: [
                Flexible(
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.buildPhase,
                    icon: Icons.build,
                    isSelected: selectedPhase == frameAnalysis.buildPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                ),
                Flexible(
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.layoutPhase,
                    icon: Icons.auto_awesome_mosaic,
                    isSelected: selectedPhase == frameAnalysis.layoutPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                ),
                Flexible(
                  fit: FlexFit.tight,
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.paintPhase,
                    icon: Icons.format_paint,
                    isSelected: selectedPhase == frameAnalysis.paintPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                ),
              ],
            ),
            const SizedBox(height: denseSpacing),
            const Text('Raster phase:'),
            const SizedBox(height: denseSpacing),
            Row(
              children: [
                Expanded(
                  child: FramePhaseBlock(
                    framePhase: frameAnalysis.rasterPhase,
                    icon: Icons.grid_on,
                    isSelected: selectedPhase == frameAnalysis.rasterPhase,
                    onSelected: frameAnalysis.selectFramePhase,
                  ),
                )
              ],
            ),
            // TODO(kenz): show flame chart of selected events here.
          ],
        );
      },
    );
  }
}

class FramePhaseBlock extends StatelessWidget {
  const FramePhaseBlock({
    Key? key,
    required this.framePhase,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  }) : super(key: key);

  static const _height = 30.0;

  static const _selectedIndicatorHeight = 4.0;

  static const _backgroundColor = ThemedColor(
    light: Color(0xFFEEEEEE),
    dark: Color(0xFF3C4043),
  );

  static const _selectedBackgroundColor = ThemedColor(
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF5F6367),
  );

  final FramePhase framePhase;

  final IconData icon;

  final bool isSelected;

  final void Function(FramePhase) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final durationText = framePhase.duration != Duration.zero
        ? msText(framePhase.duration)
        : '--';
    return InkWell(
      onTap: () => onSelected(framePhase),
      child: Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [
          Container(
            color: isSelected
                ? _selectedBackgroundColor.colorFor(colorScheme)
                : _backgroundColor.colorFor(colorScheme),
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: densePadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: defaultIconSize,
                ),
                const SizedBox(width: denseSpacing),
                Text('${framePhase.title} - $durationText'),
              ],
            ),
          ),
          if (isSelected)
            Container(
              color: defaultSelectionColor,
              height: _selectedIndicatorHeight,
            ),
        ],
      ),
    );
  }
}
