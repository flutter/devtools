// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/primitives/trees.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_model.dart';
import '../flutter_frames/flutter_frame_model.dart';

class FrameAnalysis {
  FrameAnalysis(this.frame);

  final FlutterFrame frame;

  static const saveLayerEventName = 'Canvas::saveLayer';

  static const intrinsicsEventSuffix = ' intrinsics';

  /// Data for the build phase of [frame].
  ///
  /// This is drawn from all the "Build" events on the UI thread. For a single
  /// flutter frame, there can be more than one build event, and this data may
  /// overlap with a portion of the [layoutPhase] if "Build" timeline events are
  /// children of the "Layout" event.
  ///
  /// Example:
  /// [-----Build----][-----------------Layout-----------------]
  ///                       [--Build--]     [----Build----]
  late FramePhase buildPhase = _generateBuildPhase();

  FramePhase _generateBuildPhase() {
    final uiEvent = frame.timelineEventData.uiEvent;
    if (uiEvent == null) {
      return FramePhase.build(events: <SyncTimelineEvent>[]);
    }
    final buildEvents = uiEvent
        .nodesWithCondition(
          (event) => FramePhaseType.build.isMatchForEventName(event.name),
        )
        .cast<SyncTimelineEvent>();
    return FramePhase.build(events: buildEvents);
  }

  /// Data for the layout phase of [frame].
  ///
  /// This is drawn from the "Layout" timeline event on the UI thread. This data
  /// may overlap with a portion of the [buildPhase] if "Build" timeline events
  /// are children of the "Layout" event. If this is the case, the
  /// [FramePhase.duration] for this phase will only include time that is spent
  /// in the Layout event, outside of the Build events.
  ///
  /// Example:
  /// [-----------------Layout-----------------]
  ///    [--Build--]     [----Build----]
  late FramePhase layoutPhase = _generateLayoutPhase();

  FramePhase _generateLayoutPhase() {
    final uiEvent = frame.timelineEventData.uiEvent;
    if (uiEvent != null) {
      final layoutEvent = uiEvent.firstChildWithCondition(
        (event) => FramePhaseType.layout.isMatchForEventName(event.name),
      );

      if (layoutEvent != null) {
        final buildChildren = layoutEvent.shallowNodesWithCondition(
          (event) => FramePhaseType.build.isMatchForEventName(event.name),
        );
        final buildDuration = buildChildren.fold<Duration>(
          Duration.zero,
          (previous, TimelineEvent event) {
            return previous + event.time.duration;
          },
        );

        return FramePhase.layout(
          events: <SyncTimelineEvent>[layoutEvent as SyncTimelineEvent],
          duration: layoutEvent.time.duration - buildDuration,
        );
      }
    }
    return FramePhase.layout(events: <SyncTimelineEvent>[]);
  }

  /// Data for the Paint phase of [frame].
  ///
  /// This is drawn from the "Paint" timeline event on the UI thread
  late FramePhase paintPhase = _generatePaintPhase();

  FramePhase _generatePaintPhase() {
    final uiEvent = frame.timelineEventData.uiEvent;
    if (uiEvent == null) {
      return FramePhase.paint(events: <SyncTimelineEvent>[]);
    }
    final paintEvent = uiEvent.firstChildWithCondition(
      (event) => FramePhaseType.paint.isMatchForEventName(event.name),
    );
    return FramePhase.paint(
      events: <SyncTimelineEvent>[
        if (paintEvent != null) paintEvent as SyncTimelineEvent,
      ],
    );
  }

  /// Data for the raster phase of [frame].
  ///
  /// This is drawn from all events for this frame from the raster thread.
  late FramePhase rasterPhase = FramePhase.raster(
    events: [
      if (frame.timelineEventData.rasterEvent != null)
        frame.timelineEventData.rasterEvent!,
    ],
  );

  late FramePhase longestUiPhase = _calculateLongestFramePhase();

  bool get hasUiData => _hasUiData ??= [
        ...buildPhase.events,
        ...layoutPhase.events,
        ...paintPhase.events,
      ].isNotEmpty;

  bool? _hasUiData;

  bool get hasRasterData => _hasRasterData ??= rasterPhase.events.isNotEmpty;

  bool? _hasRasterData;

  FramePhase _calculateLongestFramePhase() {
    var longestPhaseTime = Duration.zero;
    late FramePhase longest;
    for (final block in [buildPhase, layoutPhase, paintPhase]) {
      if (block.duration >= longestPhaseTime) {
        longest = block;
        longestPhaseTime = block.duration;
      }
    }
    return longest;
  }

  bool get hasExpensiveOperations =>
      saveLayerCount + intrinsicOperationsCount > 0;

  int? _saveLayerCount;
  int get saveLayerCount {
    if (_saveLayerCount == null) {
      _countExpensiveOperations();
    }
    return _saveLayerCount!;
  }

  int? _intrinsicOperationsCount;
  int get intrinsicOperationsCount {
    if (_intrinsicOperationsCount == null) {
      _countExpensiveOperations();
    }
    return _intrinsicOperationsCount!;
  }

  void _countExpensiveOperations() {
    assert(_saveLayerCount == null);
    assert(_intrinsicOperationsCount == null);
    int saveLayer = 0;
    for (final paintEvent in paintPhase.events) {
      breadthFirstTraversal<TimelineEvent>(
        paintEvent,
        action: (event) {
          if (event.name!.caseInsensitiveContains(saveLayerEventName)) {
            saveLayer++;
          }
        },
      );
    }
    _saveLayerCount = saveLayer;

    int intrinsics = 0;
    for (final layoutEvent in layoutPhase.events) {
      breadthFirstTraversal<TimelineEvent>(
        layoutEvent,
        action: (event) {
          if (event.name!.caseInsensitiveContains(intrinsicsEventSuffix)) {
            intrinsics++;
          }
        },
      );
    }
    _intrinsicOperationsCount = intrinsics;
  }

  int? buildFlex;

  int? layoutFlex;

  int? paintFlex;

  int? rasterFlex;

  int? shaderCompilationFlex;

  void calculateFramePhaseFlexValues() {
    final totalUiTimeMicros =
        (buildPhase.duration + layoutPhase.duration + paintPhase.duration)
            .inMicroseconds;
    buildFlex = _flexForPhase(buildPhase, totalUiTimeMicros);
    layoutFlex = _flexForPhase(layoutPhase, totalUiTimeMicros);
    paintFlex = _flexForPhase(paintPhase, totalUiTimeMicros);

    if (frame.hasShaderTime) {
      final totalRasterMicros = frame.rasterTime.inMicroseconds;
      final shaderMicros = frame.shaderDuration.inMicroseconds;
      final otherRasterMicros = totalRasterMicros - shaderMicros;
      shaderCompilationFlex = _calculateFlex(shaderMicros, totalRasterMicros);
      rasterFlex = _calculateFlex(otherRasterMicros, totalRasterMicros);
    } else {
      rasterFlex = 1;
    }
  }

  int _flexForPhase(FramePhase phase, int totalTimeMicros) {
    final totalPaintTimeMicros = phase.duration.inMicroseconds;
    final uiEvent = frame.timelineEventData.uiEvent;
    if (uiEvent == null) return 1;
    return _calculateFlex(totalPaintTimeMicros, totalTimeMicros);
  }

  int _calculateFlex(int numeratorMicros, int denominatorMicros) {
    if (numeratorMicros == 0 && denominatorMicros == 0) return 1;
    return ((numeratorMicros / denominatorMicros) * 100).round();
  }
}

enum FramePhaseType {
  build,
  layout,
  paint,
  raster;

  static const _buildEventName = 'Build';

  static const _layoutEventName = 'Layout (root)';

  static const _layoutEventNameLegacy = 'Layout';

  static const _paintEventName = 'Paint (root)';

  static const _paintEventNameLegacy = 'Paint';

  static const _rasterEventName = 'Raster';

  String get display {
    switch (this) {
      case build:
        return _buildEventName;
      case layout:
        return _layoutEventNameLegacy;
      case paint:
        return _paintEventNameLegacy;
      case raster:
        return _rasterEventName;
    }
  }

  bool isMatchForEventName(String? eventName) {
    switch (this) {
      case build:
        return _buildEventName.caseInsensitiveEquals(eventName);
      case layout:
        return _layoutEventName.caseInsensitiveEquals(eventName) ||
            _layoutEventNameLegacy.caseInsensitiveEquals(eventName);
      case paint:
        return _paintEventName.caseInsensitiveEquals(eventName) ||
            _paintEventNameLegacy.caseInsensitiveEquals(eventName);
      case raster:
        throw StateError('Raster events should not be matched by event name');
    }
  }
}

class FramePhase {
  FramePhase._({
    required this.type,
    required this.events,
    Duration? duration,
  })  : title = type.display,
        duration = duration ??
            events.fold<Duration>(Duration.zero, (previous, event) {
              return previous + event.time.duration;
            });

  factory FramePhase.build({
    required List<SyncTimelineEvent> events,
    Duration? duration,
  }) {
    return FramePhase._(
      type: FramePhaseType.build,
      events: events,
      duration: duration,
    );
  }

  factory FramePhase.layout({
    required List<SyncTimelineEvent> events,
    Duration? duration,
  }) {
    return FramePhase._(
      type: FramePhaseType.layout,
      events: events,
      duration: duration,
    );
  }

  factory FramePhase.paint({
    required List<SyncTimelineEvent> events,
    Duration? duration,
  }) {
    return FramePhase._(
      type: FramePhaseType.paint,
      events: events,
      duration: duration,
    );
  }

  factory FramePhase.raster({
    required List<SyncTimelineEvent> events,
    Duration? duration,
  }) {
    return FramePhase._(
      type: FramePhaseType.raster,
      events: events,
      duration: duration,
    );
  }

  final String title;

  final FramePhaseType type;

  final List<SyncTimelineEvent> events;

  final Duration duration;
}
