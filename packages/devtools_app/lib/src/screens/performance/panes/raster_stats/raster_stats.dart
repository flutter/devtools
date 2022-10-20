// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../primitives/utils.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/dialogs.dart';
import '../../../../shared/split.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_data.dart';
import '../../../../shared/theme.dart';
import '../../../../shared/utils.dart';
import '../../../../ui/colors.dart';
import 'raster_stats_controller.dart';
import 'raster_stats_model.dart';

class RenderingLayerVisualizer extends StatelessWidget {
  const RenderingLayerVisualizer({
    Key? key,
    required this.rasterStatsController,
  }) : super(key: key);

  final RasterStatsController rasterStatsController;

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<RasterStats, bool>(
      firstListenable: rasterStatsController.rasterStats,
      secondListenable: rasterStatsController.loadingSnapshot,
      builder: (context, rasterStats, loading, _) {
        if (loading) {
          return const CenteredCircularProgressIndicator();
        }
        final snapshots = rasterStats.layerSnapshots;
        if (snapshots.isEmpty) {
          return const Center(
            child: Text(
              'Take a snapshot to view raster stats for the current screen.',
            ),
          );
        }
        return Split(
          axis: Axis.horizontal,
          initialFractions: const [0.5, 0.5],
          children: [
            LayerSnapshotTable(
              controller: rasterStatsController,
              snapshots: snapshots,
            ),
            ValueListenableBuilder<LayerSnapshot?>(
              valueListenable: rasterStatsController.selectedSnapshot,
              builder: (context, snapshot, _) {
                return LayerImage(
                  snapshot: snapshot,
                  originalFrameSize:
                      rasterStatsController.rasterStats.value.originalFrameSize,
                  includeFullScreenButton: true,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class LayerSnapshotTable extends StatelessWidget {
  const LayerSnapshotTable({
    Key? key,
    required this.controller,
    required this.snapshots,
  }) : super(key: key);

  final RasterStatsController controller;

  final List<LayerSnapshot> snapshots;

  static final ColumnData<LayerSnapshot> _layerColumn = _LayerColumn();

  static final ColumnData<LayerSnapshot> _timeColumn = _RenderingTimeColumn();

  static final ColumnData<LayerSnapshot> _percentageColumn =
      _RenderingTimePercentageColumn();

  static final List<ColumnData<LayerSnapshot>> _columns = [
    _layerColumn,
    _timeColumn,
    _percentageColumn
  ];

  @override
  Widget build(BuildContext context) {
    final borderSide = defaultBorderSide(Theme.of(context));
    return Container(
      decoration: BoxDecoration(
        border: Border(right: borderSide),
      ),
      child: FlatTable<LayerSnapshot>(
        keyFactory: (LayerSnapshot snapshot) =>
            ValueKey<String?>('${snapshot.id}'),
        data: snapshots,
        dataKey: 'raster-layer-snapshots',
        columns: _columns,
        defaultSortColumn: _percentageColumn,
        defaultSortDirection: SortDirection.descending,
        onItemSelected: controller.selectSnapshot,
        selectionNotifier: controller.selectedSnapshot,
      ),
    );
  }
}

class _LayerColumn extends ColumnData<LayerSnapshot> {
  _LayerColumn()
      : super(
          'Layer',
          fixedWidthPx: scaleByFontFactor(150),
        );

  @override
  String getValue(LayerSnapshot dataObject) => dataObject.displayName;
}

class _RenderingTimeColumn extends ColumnData<LayerSnapshot> {
  _RenderingTimeColumn()
      : super(
          'Rendering time',
          fixedWidthPx: scaleByFontFactor(120),
        );

  @override
  int getValue(LayerSnapshot dataObject) => dataObject.duration.inMicroseconds;

  @override
  String getDisplayValue(LayerSnapshot dataObject) =>
      msText(dataObject.duration);

  @override
  bool get numeric => true;
}

class _RenderingTimePercentageColumn extends ColumnData<LayerSnapshot> {
  _RenderingTimePercentageColumn()
      : super(
          'Percent rendering time',
          fixedWidthPx: scaleByFontFactor(180),
        );

  @override
  double getValue(LayerSnapshot dataObject) =>
      dataObject.percentRenderingTimeAsDouble;

  @override
  String getDisplayValue(LayerSnapshot dataObject) =>
      dataObject.percentRenderingTimeDisplay;

  @override
  bool get numeric => true;
}

class LayerImage extends StatelessWidget {
  const LayerImage({
    Key? key,
    required this.snapshot,
    required this.originalFrameSize,
    this.includeFullScreenButton = false,
  }) : super(key: key);

  final LayerSnapshot? snapshot;

  final Size? originalFrameSize;

  final bool includeFullScreenButton;

  double get _fullscreenButtonWidth => defaultButtonHeight + denseSpacing * 2;

  static const _placeholderImageSize = 60.0;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    final originalFrameSize = this.originalFrameSize;
    if (snapshot == null || originalFrameSize == null) {
      return const Icon(
        Icons.image,
        size: _placeholderImageSize,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width:
              includeFullScreenButton ? _fullscreenButtonWidth : defaultSpacing,
        ),
        Flexible(
          child: Container(
            color: Theme.of(context).focusColor,
            margin: const EdgeInsets.symmetric(horizontal: defaultSpacing),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scaleFactor = _calculateScaleFactor(
                  constraints,
                  originalFrameSize,
                );
                final scaledSize = _scaledLayerSize(scaleFactor);
                final scaledOffset = _scaledLayerOffset(scaleFactor);
                return Stack(
                  children: [
                    Image.memory(snapshot.bytes),
                    Positioned(
                      left: scaledOffset.dx,
                      top: scaledOffset.dy,
                      child: Container(
                        height: scaledSize.height,
                        width: scaledSize.width,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: defaultSelectionColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        includeFullScreenButton
            ? _FullScreenButton(
                snapshot: snapshot,
                originalFrameSize: originalFrameSize,
              )
            : const SizedBox(width: defaultSpacing),
      ],
    );
  }

  double _calculateScaleFactor(
    BoxConstraints constraints,
    Size originalFrameSize,
  ) {
    final widthScaleFactor = constraints.maxWidth / originalFrameSize.width;
    final heightScaleFactor = constraints.maxHeight / originalFrameSize.height;
    return math.min(widthScaleFactor, heightScaleFactor);
  }

  Size _scaledLayerSize(double scale) {
    final layerSnapshot = snapshot!;
    final scaledWidth = layerSnapshot.size.width * scale;
    final scaledHeight = layerSnapshot.size.height * scale;
    return Size(scaledWidth, scaledHeight);
  }

  Offset _scaledLayerOffset(double scale) {
    final layerSnapshot = snapshot!;
    final scaledDx = layerSnapshot.offset.dx * scale;
    final scaledDy = layerSnapshot.offset.dy * scale;
    return Offset(scaledDx, scaledDy);
  }
}

class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton({
    Key? key,
    required this.snapshot,
    required this.originalFrameSize,
  }) : super(key: key);

  final LayerSnapshot snapshot;

  final Size originalFrameSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: denseSpacing),
      alignment: Alignment.bottomRight,
      child: IconButton(
        icon: Icon(
          Icons.fullscreen,
          size: defaultButtonHeight,
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => LayerImageDialog(
              snapshot: snapshot,
              originalFrameSize: originalFrameSize,
            ),
          );
        },
      ),
    );
  }
}

class LayerImageDialog extends StatelessWidget {
  const LayerImageDialog({
    Key? key,
    required this.snapshot,
    required this.originalFrameSize,
  }) : super(key: key);

  final LayerSnapshot snapshot;

  final Size originalFrameSize;

  static const _padding = 300.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final mediaWidth = media.size.width;
    final mediaHeight = media.size.height;
    return DevToolsDialog(
      includeDivider: false,
      scrollable: false,
      content: Container(
        width: mediaWidth - _padding,
        height: mediaHeight - _padding,
        child: LayerImage(
          snapshot: snapshot,
          originalFrameSize: originalFrameSize,
        ),
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}
