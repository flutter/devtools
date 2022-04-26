// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config_specific/logger/logger.dart' as logger;
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/globals.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';

// TODO(kenz): add analytics once [rasterMetricsSupported] is enabled by default

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
            child: Text(
              'Take a snapshot to view raster metrics for the current screen.',
            ),
          );
        }
        return Split(
          axis: Axis.horizontal,
          initialFractions: const [0.5, 0.5],
          children: [
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
          ],
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
      child: FlatTable<LayerSnapshot>(
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
      children: [
        SizedBox(
          width:
              includeFullscreenButton ? _fullscreenButtonWidth : defaultSpacing,
        ),
        Flexible(
          child: Container(
            color: color,
            margin: const EdgeInsets.symmetric(horizontal: defaultSpacing),
            child: Image.memory(snapshot.bytes),
          ),
        ),
        includeFullscreenButton
            ? Container(
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
                      ),
                    );
                  },
                ),
              )
            : const SizedBox(width: defaultSpacing),
      ],
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
        child: LayerImage(
          snapshot: snapshot,
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

class RasterMetricsController {
  static const _snapshotsJsonKey = 'snapshots';

  static const _snapshotJsonKey = 'snapshot';

  static const _layerIdKey = 'layer_unique_id';

  static const _durationKey = 'duration_micros';

  ValueListenable<List<LayerSnapshot>> get layerSnapshots => _layerSnapshots;

  final _layerSnapshots = ValueNotifier<List<LayerSnapshot>>([]);

  ValueListenable<LayerSnapshot?> get selectedSnapshot => _selectedSnapshot;

  final _selectedSnapshot = ValueNotifier<LayerSnapshot?>(null);

  ValueListenable<bool> get loadingSnapshot => _loadingSnapshot;

  final _loadingSnapshot = ValueNotifier<bool>(false);

  Duration _sumRasterTime = Duration.zero;

  void selectSnapshot(LayerSnapshot? snapshot) {
    _selectedSnapshot.value = snapshot;
  }

  Future<void> collectRasterStats() async {
    clear();
    _loadingSnapshot.value = true;
    try {
      final response = await serviceManager.renderFrameWithRasterStats;
      final json = response?.json ?? <String, Object?>{};
      await initDataFromJson(json);
    } catch (e) {
      logger.log('Error collecting raster stats: $e');
      clear();
    } finally {
      _loadingSnapshot.value = false;
    }
  }

  void clear() {
    _layerSnapshots.value = <LayerSnapshot>[];
    _selectedSnapshot.value = null;
    _sumRasterTime = Duration.zero;
  }

  @visibleForTesting
  Future<void> initDataFromJson(Map<String, Object?> json) async {
    final snapshotsFromJson =
        (json[_snapshotsJsonKey] as List).cast<Map<String, dynamic>>();
    final snapshots = <LayerSnapshot>[];
    for (final snapshot in snapshotsFromJson) {
      final id = snapshot[_layerIdKey];
      final dur = Duration(microseconds: snapshot[_durationKey] as int);
      final imageBytes = Uint8List.fromList(
        (snapshot[_snapshotJsonKey] as List<dynamic>).cast<int>(),
      );
      final image = await imageFromBytes(imageBytes);
      final layerSnapshot = LayerSnapshot(
        id: id,
        duration: dur,
        image: image,
        bytes: imageBytes,
      );
      snapshots.add(layerSnapshot);
      _sumRasterTime += dur;
    }

    for (final snapshot in snapshots) {
      snapshot.totalRenderingDuration = _sumRasterTime;
    }

    // Sort by percent rendering time in descending order.
    snapshots.sort(
      (a, b) => b.percentRenderingTimeAsDouble
          .compareTo(a.percentRenderingTimeAsDouble),
    );

    _layerSnapshots.value = snapshots;
    _selectedSnapshot.value = snapshots.safeFirst;
  }

  Future<ui.Image> imageFromBytes(Uint8List bytes) async {
    return await decodeImageFromList(bytes);
  }
}

class LayerSnapshot {
  LayerSnapshot({
    required this.id,
    required this.duration,
    required this.image,
    required this.bytes,
  });

  final int id;

  final Duration duration;

  final ui.Image image;

  final Uint8List bytes;

  /// The total rendering time for the set of snapshots that this
  /// [LayerSnapshot] is a part of.
  ///
  /// This will be set after this [LayerSnapshot] is created, once all the
  /// [LayerSnapshot]s in a set have been processed.
  Duration? totalRenderingDuration;

  double get percentRenderingTimeAsDouble =>
      duration.inMicroseconds / totalRenderingDuration!.inMicroseconds;

  String get percentRenderingTimeDisplay =>
      percent2(percentRenderingTimeAsDouble);

  String get displayName => 'Layer $id';
}
