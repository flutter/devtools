// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/charts/flame_chart.dart';
import '../../../shared/ui/colors.dart';
import '../../../shared/ui/utils.dart';
import '../cpu_profile_model.dart';

class CpuProfileFlameChart extends FlameChart<CpuProfileData, CpuStackFrame?> {
  CpuProfileFlameChart({
    super.key,
    required CpuProfileData data,
    required double width,
    required double height,
    required ValueListenable<CpuStackFrame?> selectionNotifier,
    required ValueListenable<List<CpuStackFrame>> searchMatchesNotifier,
    required ValueListenable<CpuStackFrame?> activeSearchMatchNotifier,
    required void Function(CpuStackFrame? stackFrame) onDataSelected,
  }) : super(
          data,
          time: data.profileMetaData.time!,
          containerWidth: width,
          containerHeight: height,
          startInset: sideInsetSmall,
          endInset: sideInsetSmall,
          selectionNotifier: selectionNotifier,
          searchMatchesNotifier: searchMatchesNotifier,
          activeSearchMatchNotifier: activeSearchMatchNotifier,
          onDataSelected: onDataSelected,
        );

  @override
  State<CpuProfileFlameChart> createState() => _CpuProfileFlameChartState();
}

class _CpuProfileFlameChartState
    extends FlameChartState<CpuProfileFlameChart, CpuStackFrame> {
  static const stackFramePadding = 1;

  final stackFrameLefts = <String, double>{};

  @override
  void initFlameChartElements() {
    super.initFlameChartElements();
    expandRows(
      widget.data.cpuProfileRoot.depth +
          rowOffsetForTopPadding +
          FlameChart.rowOffsetForBottomPadding,
    );

    void createChartNodes(CpuStackFrame stackFrame, int row) {
      final double width =
          widget.startingContentWidth * stackFrame.totalTimeRatio -
              stackFramePadding;
      final left = startingLeftForStackFrame(stackFrame);
      final colorPair = _colorPairForStackFrame(stackFrame);

      final node = FlameChartNode<CpuStackFrame>(
        key: Key(stackFrame.id),
        text: stackFrame.name,
        rect: Rect.fromLTWH(left, flameChartNodeTop, width, chartRowHeight),
        colorPair: colorPair,
        data: stackFrame,
        onSelected: (CpuStackFrame frame) => widget.onDataSelected(frame),
      )..sectionIndex = 0;

      rows[row].addNode(node);

      for (final child in stackFrame.children) {
        createChartNodes(child, row + 1);
      }
    }

    createChartNodes(widget.data.cpuProfileRoot, rowOffsetForTopPadding);
  }

  @override
  List<Widget> buildChartOverlays(
    BoxConstraints constraints,
    BuildContext buildContext,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      CustomPaint(
        painter: TimelineGridPainter(
          zoom: currentZoom,
          constraints: constraints,
          verticalScrollOffset: verticalScrollOffset,
          horizontalScrollOffset: horizontalScrollOffset,
          chartStartInset: widget.startInset,
          chartEndInset: widget.endInset,
          flameChartWidth: widthWithZoom,
          duration: widget.time.duration,
          colorScheme: colorScheme,
        ),
      ),
    ];
  }

  @override
  bool isDataVerticallyInView(CpuStackFrame data) {
    final verticalScrollOffset = verticalControllerGroup.offset;
    final stackFrameTopY = topYForData(data);
    return stackFrameTopY > verticalScrollOffset &&
        stackFrameTopY + rowHeightWithPadding <
            verticalScrollOffset + widget.containerHeight;
  }

  @override
  bool isDataHorizontallyInView(CpuStackFrame data) {
    final horizontalScrollOffset = horizontalControllerGroup.offset;
    final startX = startXForData(data);
    return startX >= horizontalScrollOffset &&
        startX <= horizontalScrollOffset + widget.containerWidth;
  }

  @override
  double topYForData(CpuStackFrame data) {
    return data.level * rowHeightWithPadding;
  }

  @override
  double startXForData(CpuStackFrame data) {
    final x = stackFrameLefts[data.id]! - widget.startInset;
    return x * currentZoom;
  }

  double startingLeftForStackFrame(CpuStackFrame stackFrame) {
    final CpuStackFrame? parent = stackFrame.parent;
    late double left;
    if (parent == null) {
      left = widget.startInset;
    } else {
      final stackFrameIndex = stackFrame.index;
      if (stackFrameIndex == 0) {
        // This is the first child of parent. [left] should equal the left
        // value of [stackFrame]'s parent.
        left = stackFrameLefts[parent.id]!;
      } else {
        assert(stackFrameIndex != -1);
        // [stackFrame] is not the first child of its parent. [left] should
        // equal the right value of its previous sibling.
        final CpuStackFrame previous = parent.children[stackFrameIndex - 1];
        left = stackFrameLefts[previous.id]! +
            (widget.startingContentWidth * previous.totalTimeRatio);
      }
    }
    stackFrameLefts[stackFrame.id] = left;
    return left;
  }

  ThemedColorPair _colorPairForStackFrame(CpuStackFrame stackFrame) {
    if (stackFrame.isNative) return nativeCodeColor;
    if (stackFrame.isDartCore) return dartCoreColor;
    if (stackFrame.isFlutterCore) return flutterCoreColor;
    return appCodeColor;
  }
}
