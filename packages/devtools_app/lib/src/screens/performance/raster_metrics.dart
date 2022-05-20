// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import 'raster_metrics_controller.dart';

class RenderingLayerVisualizer extends StatelessWidget {
  const RenderingLayerVisualizer({
    Key? key,
    required this.rasterMetricsController,
  }) : super(key: key);

  final RasterMetricsController rasterMetricsController;

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<List<LayerSnapshot>, bool>(
      firstListenable: rasterMetricsController.layerSnapshots,
      secondListenable: rasterMetricsController.loadingSnapshot,
      builder: (context, snapshots, loading, _) {
        if (loading) {
          return const CenteredCircularProgressIndicator();
        }
        if (snapshots.isEmpty) {
          return const Center(
            Text(
              'Take a snapshot to view raster metrics for the current screen.',
            ),
          );
        }
        return Split(
          axis: Axis.horizontal,
          initialFractions: const [0.5, 0.5],
          LayerSnapshotTable(
            controller: rasterMetricsController,
            snapshots: snapshots,
          ),
          ValueListenableBuilder<LayerSnapshot?>(
            valueListenable: rasterMetricsController.selectedSnapshot,
            builder: (context, snapshot, _) {
              return LayerImage(
                snapshot: snapshot,
                includeFullscreenButton: true,
              );
            },
          ),
        );
      },
    );
  }
}

class LayerSnapshotTable extends StatelessWidget {
  LayerSnapshotTable({
    Key? key,
    required this.controller,
    required this.snapshots,
  }) : super(key: key);

  final RasterMetricsController controller;

  final List<LayerSnapshot> snapshots;

  final ColumnData<LayerSnapshot> _layerColumn = _LayerColumn();

  final ColumnData<LayerSnapshot> _percentageColumn =
      _RenderingTimePercentageColumn();

  List<ColumnData<LayerSnapshot>> get _columns =>
      [_layerColumn, _percentageColumn];

  @override
  Widget build(BuildContext context) {
    final borderSide = defaultBorderSide(Theme.of(context));
    return Container(
      decoration: BoxDecoration(
        border: Border(right: borderSide),
      ),
      FlatTable<LayerSnapshot>(
        columns: _columns,
        data: snapshots,
        keyFactory: (LayerSnapshot snapshot) =>
            ValueKey<String?>('${snapshot.id}'),
        sortColumn: _percentageColumn,
        sortDirection: SortDirection.descending,
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
    this.includeFullscreenButton = false,
  }) : super(key: key);

  final LayerSnapshot? snapshot;

  final bool includeFullscreenButton;

  double get _fullscreenButtonWidth => defaultButtonHeight + denseSpacing * 2;

  static const _placeholderImageSize = 60.0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).focusColor;
    final snapshot = this.snapshot;
    if (snapshot == null) {
      return const Icon(
        Icons.image,
        size: _placeholderImageSize,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      SizedBox(
        width:
            includeFullscreenButton ? _fullscreenButtonWidth : defaultSpacing,
      ),
      Flexible(
        Container(
          color: color,
          margin: const EdgeInsets.symmetric(horizontal: defaultSpacing),
          Image.memory(snapshot.bytes),
        ),
      ),
      includeFullscreenButton
          ? Container(
              padding: const EdgeInsets.only(bottom: denseSpacing),
              alignment: Alignment.bottomRight,
              IconButton(
                icon: Icon(
                  Icons.fullscreen,
                  size: defaultButtonHeight,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => LayerImageDialog(
                      snapshot: snapshot,
                    ),
                  );
                },
              ),
            )
          : const SizedBox(width: defaultSpacing),
    );
  }
}

class LayerImageDialog extends StatelessWidget {
  const LayerImageDialog({Key? key, required this.snapshot}) : super(key: key);

  final LayerSnapshot snapshot;

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
        LayerImage(
          snapshot: snapshot,
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}
