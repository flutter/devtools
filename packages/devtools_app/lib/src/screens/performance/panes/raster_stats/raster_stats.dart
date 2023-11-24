// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/table/table.dart';
import '../../../../shared/table/table_data.dart';
import '../../performance_utils.dart';
import 'raster_stats_controller.dart';
import 'raster_stats_model.dart';

class RasterStatsView extends StatelessWidget {
  const RasterStatsView({
    super.key,
    required this.rasterStatsController,
    required this.impellerEnabled,
  });

  final RasterStatsController rasterStatsController;

  final bool impellerEnabled;

  @override
  Widget build(BuildContext context) {
    if (impellerEnabled) {
      return Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: 'The Raster Stats tool is not currently available for the '
                'Impeller backend.\nLearn more about the status of ',
            style: Theme.of(context).regularTextStyle,
            children: [
              LinkTextSpan(
                link: Link(
                  display: 'Impeller',
                  url: impellerDocsUrl,
                  gaScreenName: gac.performance,
                  gaSelectedItemDescription:
                      gac.PerformanceDocs.impellerDocsLinkFromRasterStats.name,
                ),
                context: context,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (!offlineController.offlineMode.value)
          _RasterStatsControls(
            rasterStatsController: rasterStatsController,
          ),
        Expanded(
          child: _LayerVisualizer(
            rasterStatsController: rasterStatsController,
          ),
        ),
      ],
    );
  }
}

class _RasterStatsControls extends StatelessWidget {
  const _RasterStatsControls({required this.rasterStatsController});

  final RasterStatsController rasterStatsController;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration.onlyBottom(
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: Row(
          children: [
            GaDevToolsButton(
              tooltip: 'Take a snapshot of the rendering layers on the current'
                  ' screen',
              icon: Icons.camera_outlined,
              label: 'Take Snapshot',
              gaScreen: gac.performance,
              gaSelection: gac.PerformanceEvents.collectRasterStats.name,
              onPressed: rasterStatsController.collectRasterStats,
            ),
            const SizedBox(width: denseSpacing),
            ClearButton(
              gaScreen: gac.performance,
              gaSelection: gac.PerformanceEvents.clearRasterStats.name,
              onPressed: rasterStatsController.clearData,
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerVisualizer extends StatefulWidget {
  const _LayerVisualizer({required this.rasterStatsController});

  final RasterStatsController rasterStatsController;

  @override
  State<_LayerVisualizer> createState() => _LayerVisualizerState();
}

class _LayerVisualizerState extends State<_LayerVisualizer> {
  ValueNotifier<Color>? _rasterPreviewBackgroundColor;

  @override
  Widget build(BuildContext context) {
    _rasterPreviewBackgroundColor ??= ValueNotifier<Color>(
      _BackgroundColorButton.defaultBackgroundColor(context),
    );

    return MultiValueListenableBuilder(
      listenables: [
        widget.rasterStatsController.rasterStats,
        widget.rasterStatsController.loadingSnapshot,
      ],
      builder: (context, values, _) {
        final rasterStats = values.first as RasterStats?;
        final loading = values.second as bool;
        if (loading) {
          return const CenteredCircularProgressIndicator();
        }
        if (rasterStats == null || rasterStats.layerSnapshots.isEmpty) {
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
              controller: widget.rasterStatsController,
              snapshots: rasterStats.layerSnapshots,
            ),
            ValueListenableBuilder<LayerSnapshot?>(
              valueListenable: widget.rasterStatsController.selectedSnapshot,
              builder: (context, snapshot, _) {
                return LayerImage(
                  snapshot: snapshot,
                  originalFrameSize: rasterStats.originalFrameSize,
                  includeFullScreenButton: true,
                  rasterPreviewBackgroundColor: _rasterPreviewBackgroundColor!,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
class LayerSnapshotTable extends StatelessWidget {
  const LayerSnapshotTable({
    Key? key,
    required this.controller,
    required this.snapshots,
  }) : super(key: key);

  static final _layerColumn = _LayerColumn();
  static final _timeColumn = _RenderingTimeColumn();
  static final _percentageColumn = _RenderingTimePercentageColumn();
  static final _columns = <ColumnData<LayerSnapshot>>[
    _layerColumn,
    _timeColumn,
    _percentageColumn,
  ];

  final RasterStatsController controller;

  final List<LayerSnapshot> snapshots;

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
      durationText(dataObject.duration);

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

@visibleForTesting
class LayerImage extends StatelessWidget {
  const LayerImage({
    Key? key,
    required this.snapshot,
    required this.originalFrameSize,
    required ValueNotifier<Color> rasterPreviewBackgroundColor,
    this.includeFullScreenButton = false,
  })  : _rasterPreviewBackgroundColor = rasterPreviewBackgroundColor,
        super(key: key);

  final ValueNotifier<Color> _rasterPreviewBackgroundColor;
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
    final theme = Theme.of(context);
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
            color: theme.focusColor,
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
                    ValueListenableBuilder(
                      valueListenable: _rasterPreviewBackgroundColor,
                      builder: (context, _, __) {
                        return Container(
                          color: _rasterPreviewBackgroundColor.value,
                          child: Image.memory(snapshot.bytes),
                        );
                      },
                    ),
                    Positioned(
                      left: scaledOffset.dx,
                      top: scaledOffset.dy,
                      child: Container(
                        height: scaledSize.height,
                        width: scaledSize.width,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary,
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
                rasterPreviewBackgroundColor: _rasterPreviewBackgroundColor,
              )
            : const SizedBox(width: defaultSpacing),
        _BackgroundColorButton(
          _rasterPreviewBackgroundColor,
        ),
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

class _BackgroundColorButton extends StatefulWidget {
  const _BackgroundColorButton(this._rasterPreviewBackgroundColor);
  final ValueNotifier<Color> _rasterPreviewBackgroundColor;
  static Color defaultBackgroundColor(BuildContext context) => Colors.grey;

  @override
  State<_BackgroundColorButton> createState() => _BackgroundColorButtonState();
}

class _BackgroundColorButtonState extends State<_BackgroundColorButton> {
  final List<Color> _colors = [Colors.grey, Colors.black, Colors.white];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        bottom: denseSpacing,
        right: denseSpacing,
      ),
      alignment: Alignment.bottomRight,
      child: DevToolsTooltip(
        message: 'Toggle the layer preview background color.',
        child: GaDevToolsButton.iconOnly(
          icon: Icons.brush,
          outlined: false,
          gaScreen: gac.performance,
          gaSelection: gac.PerformanceEvents.fullScreenLayerImage.name,
          onPressed: () {
            _index = (_index + 1) % _colors.length;
            widget._rasterPreviewBackgroundColor.value = _colors[_index];
          },
        ),
      ),
    );
  }
}

class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton(
      {Key? key,
      required this.snapshot,
      required this.originalFrameSize,
      required ValueNotifier<Color> rasterPreviewBackgroundColor})
      : _rasterPreviewBackgroundColor = rasterPreviewBackgroundColor,
        super(key: key);
  final ValueNotifier<Color> _rasterPreviewBackgroundColor;
  final LayerSnapshot snapshot;

  final Size originalFrameSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        bottom: denseSpacing,
        right: denseSpacing,
      ),
      alignment: Alignment.bottomRight,
      child: GaDevToolsButton.iconOnly(
        icon: Icons.fullscreen,
        outlined: false,
        gaScreen: gac.performance,
        gaSelection: gac.PerformanceEvents.fullScreenLayerImage.name,
        onPressed: () {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => _LayerImageDialog(
                snapshot: snapshot,
                originalFrameSize: originalFrameSize,
                rasterPreviewBackgroundColor: _rasterPreviewBackgroundColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LayerImageDialog extends StatelessWidget {
  const _LayerImageDialog({
    Key? key,
    required this.snapshot,
    required this.originalFrameSize,
    required ValueNotifier<Color> rasterPreviewBackgroundColor,
  })  : _rasterPreviewBackgroundColor = rasterPreviewBackgroundColor,
        super(key: key);

  final ValueNotifier<Color> _rasterPreviewBackgroundColor;
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
      content: SizedBox(
        width: mediaWidth - _padding,
        height: mediaHeight - _padding,
        child: LayerImage(
          snapshot: snapshot,
          originalFrameSize: originalFrameSize,
          rasterPreviewBackgroundColor: _rasterPreviewBackgroundColor,
        ),
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}
