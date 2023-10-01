// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../../shared/primitives/utils.dart';
import '../../../../shared/ui/utils.dart';
import 'frame_analysis_model.dart';

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
  @override
  void initState() {
    super.initState();
    // Do this in initState so that we do not have to pay the cost in build.
    widget.frameAnalysis.calculateFramePhaseFlexValues();
  }

  @override
  void didUpdateWidget(FrameTimeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.frameAnalysis.calculateFramePhaseFlexValues();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UiPhases(frameAnalysis: widget.frameAnalysis),
        const SizedBox(height: denseSpacing),
        _RasterPhases(frameAnalysis: widget.frameAnalysis),
      ],
    );
  }
}

class _UiPhases extends StatelessWidget {
  const _UiPhases({Key? key, required this.frameAnalysis}) : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  Widget build(BuildContext context) {
    return _FrameBlockGroup(
      title: 'UI phases:',
      data: _generateBlockData(frameAnalysis),
      hasData: frameAnalysis.hasUiData,
    );
  }

  List<_FramePhaseBlockData> _generateBlockData(FrameAnalysis frameAnalysis) {
    final buildPhase = frameAnalysis.buildPhase;
    final layoutPhase = frameAnalysis.layoutPhase;
    final paintPhase = frameAnalysis.paintPhase;
    return [
      _FramePhaseBlockData(
        title: buildPhase.title,
        duration: buildPhase.duration,
        flex: frameAnalysis.buildFlex!,
        icon: Icons.build,
      ),
      _FramePhaseBlockData(
        title: layoutPhase.title,
        duration: layoutPhase.duration,
        flex: frameAnalysis.layoutFlex!,
        icon: Icons.auto_awesome_mosaic,
      ),
      _FramePhaseBlockData(
        title: paintPhase.title,
        duration: paintPhase.duration,
        flex: frameAnalysis.paintFlex!,
        icon: Icons.format_paint,
      ),
    ];
  }
}

class _RasterPhases extends StatelessWidget {
  const _RasterPhases({Key? key, required this.frameAnalysis})
      : super(key: key);

  final FrameAnalysis frameAnalysis;

  @override
  Widget build(BuildContext context) {
    final data = _generateBlockData(frameAnalysis);
    return _FrameBlockGroup(
      title: 'Raster ${pluralize('phase', data.length)}:',
      data: data,
      hasData: frameAnalysis.hasRasterData,
    );
  }

  List<_FramePhaseBlockData> _generateBlockData(FrameAnalysis frameAnalysis) {
    final frame = frameAnalysis.frame;
    if (frame.hasShaderTime) {
      return [
        _FramePhaseBlockData(
          title: 'Shader compilation',
          duration: frame.shaderDuration,
          flex: frameAnalysis.shaderCompilationFlex!,
          icon: Icons.image_outlined,
        ),
        _FramePhaseBlockData(
          title: 'Other raster',
          duration: frame.rasterTime - frame.shaderDuration,
          flex: frameAnalysis.rasterFlex!,
          icon: Icons.grid_on,
        ),
      ];
    }
    final rasterPhase = frameAnalysis.rasterPhase;
    return [
      _FramePhaseBlockData(
        title: rasterPhase.title,
        duration: rasterPhase.duration,
        flex: frameAnalysis.rasterFlex!,
        icon: Icons.grid_on,
      ),
    ];
  }
}

class _FrameBlockGroup extends StatelessWidget {
  const _FrameBlockGroup({
    Key? key,
    required this.title,
    required this.data,
    required this.hasData,
  }) : super(key: key);

  final String title;

  final List<_FramePhaseBlockData> data;

  final bool hasData;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (hasData) {
      final totalFlex =
          data.fold<int>(0, (current, block) => current + block.flex);
      content = LayoutBuilder(
        builder: (context, constraints) {
          final adjustedBlockWidths =
              adjustedWidthsForBlocks(constraints, totalFlex);
          return Row(
            children: [
              for (var i = 0; i < data.length; i++)
                _FramePhaseBlock(
                  blockData: data[i],
                  width: adjustedBlockWidths[i],
                ),
            ],
          );
        },
      );
    } else {
      content = const Text('Data not available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: denseSpacing),
        content,
      ],
    );
  }

  /// Returns a list of adjusted widths for each block.
  ///
  /// The adjusted widths will ensure each block is at least
  /// [_FramePhaseBlock.minBlockWidth] wide, and will modify surrounding block
  /// widths to accommodate.
  List<double> adjustedWidthsForBlocks(
    BoxConstraints constraints,
    int totalFlex,
  ) {
    final unadjustedBlockWidths = data
        .map(
          (blockData) => constraints.maxWidth * blockData.flex / totalFlex,
        )
        .toList();

    var adjustment = 0.0;
    var widestBlockIndex = 0;
    for (var i = 0; i < unadjustedBlockWidths.length; i++) {
      final unadjustedWidth = unadjustedBlockWidths[i];
      final currentWidestBlock = unadjustedBlockWidths[widestBlockIndex];
      if (unadjustedWidth > currentWidestBlock) {
        widestBlockIndex = i;
      }
      if (unadjustedWidth < _FramePhaseBlock.minBlockWidth) {
        adjustment += _FramePhaseBlock.minBlockWidth - unadjustedWidth;
      }
    }

    final adjustedBlockWidths = unadjustedBlockWidths
        .map(
          (blockWidth) => math.max(blockWidth, _FramePhaseBlock.minBlockWidth),
        )
        .toList();
    final widest = adjustedBlockWidths[widestBlockIndex];
    adjustedBlockWidths[widestBlockIndex] = math.max(
      widest - adjustment,
      _FramePhaseBlock.minBlockWidth,
    );

    return adjustedBlockWidths;
  }
}

class _FramePhaseBlock extends StatelessWidget {
  const _FramePhaseBlock({
    Key? key,
    required this.blockData,
    required this.width,
  }) : super(key: key);

  static const _height = 30.0;

  static const minBlockWidth = defaultIconSizeBeforeScaling + densePadding * 8;

  static const _backgroundColor = ThemedColor(
    light: Color(0xFFEEEEEE),
    dark: Color(0xFF3C4043),
  );

  final _FramePhaseBlockData blockData;

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DevToolsTooltip(
      message: blockData.display,
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor.colorFor(colorScheme),
          border: Border.all(color: theme.focusColor),
        ),
        height: _height,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: densePadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minWidthForText = defaultIconSize +
                densePadding * 2 +
                denseSpacing +
                calculateTextSpanWidth(TextSpan(text: blockData.display));
            bool includeText = true;
            if (constraints.maxWidth < minWidthForText) {
              includeText = false;
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  blockData.icon,
                  size: defaultIconSize,
                ),
                if (includeText) ...[
                  const SizedBox(width: denseSpacing),
                  Text(
                    blockData.display,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FramePhaseBlockData {
  _FramePhaseBlockData({
    required this.title,
    required this.duration,
    required this.flex,
    required this.icon,
  });

  final String title;

  final Duration duration;

  final int flex;

  final IconData icon;

  String get display {
    final text = duration != Duration.zero
        ? durationText(
            duration,
            unit: DurationDisplayUnit.milliseconds,
            allowRoundingToZero: false,
          )
        : '--';
    return '$title - $text';
  }
}
