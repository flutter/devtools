// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:devtools_app_shared/utils.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service_protos/vm_service_protos.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/analytics/metrics.dart';
import '../../../../shared/development_helpers.dart';
import '../../../../shared/future_work_tracker.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_controller.dart';
import '../../performance_model.dart';
import '../../performance_utils.dart';
import '../flutter_frames/flutter_frame_model.dart';
import 'perfetto/perfetto_controller.dart';
import 'perfetto/tracing/model.dart';

final _log = Logger('timeline_events_controller');

enum EventsControllerStatus {
  empty,
  processing,
  ready,
}

class TimelineEventsController extends PerformanceFeatureController
    with AutoDisposeControllerMixin {
  TimelineEventsController(super.performanceController) {
    perfettoController = createPerfettoController(performanceController, this);
    addAutoDisposeListener(_workTracker.active, () {
      final active = _workTracker.active.value;
      if (active) {
        _status.value = EventsControllerStatus.processing;
      } else {
        _status.value = EventsControllerStatus.ready;
      }
    });
  }

  static const uiThreadSuffix = '.ui';
  static const rasterThreadSuffix = '.raster';
  static const gpuThreadSuffix = '.gpu';
  static const platformThreadSuffix = '.platform';
  static const flutterTestThreadSuffix = '.flutter.test..platform';

  /// Controller that contains business logic for the Perfetto trace viewer.
  late final PerfettoController perfettoController;

  /// The complete Perfetto timeline that DevTools has received from the VM.
  ///
  /// This value is built up by polling every [_timelinePollingInterval], and
  /// fetching new Perfetto timeline data from the VM. New data is continually
  /// merged with [fullPerfettoTrace] to keep this value up to date.
  Trace? fullPerfettoTrace;

  /// Track events that we have received from the VM, but have not yet
  /// processed.
  final _unprocessedTrackEvents = <PerfettoTrackEvent>[];

  /// The collection of [TimelineEvent]s that should be linked to
  /// [FlutterFrame]s but have not yet been assigned.
  ///
  /// These timeline events are keyed by the [FlutterFrame] ID specified in the
  /// event arguments, which matches the ID for the corresponding
  /// [FlutterFrame].
  final _unassignedFlutterTimelineEvents = <int, FrameTimelineEventData>{};

  /// Stores the id of the first Flutter frame that we have timeline events for.
  int? firstWellFormedFlutterFrameId;

  /// All [PerfettoTrackDescriptorEvent]s we have received from the VM timeline.
  final _trackDescriptors = <PerfettoTrackDescriptorEvent>{};

  /// Whether the recorded timeline data is currently being processed.
  ValueListenable<EventsControllerStatus> get status => _status;
  final _status =
      ValueNotifier<EventsControllerStatus>(EventsControllerStatus.empty);

  final _workTracker = FutureWorkTracker();

  Timer? _pollingTimer;

  int _nextPollStartMicros = 0;

  /// The number of requests per second that we allow for pulling the VM
  /// timeline.
  ///
  /// Passing a value of 0.5 will result in a limit of one request every two
  /// seconds.
  static const _timelinePollingRateLimit = 0.5;

  static const _timelinePollingInterval = Duration(seconds: 10);

  RateLimiter? _timelinePollingRateLimiter;

  @override
  Future<void> init() async {
    perfettoController.init();

    if (!offlineController.offlineMode.value) {
      await _initForServiceConnection();
    }
  }

  @override
  void onBecomingActive() {
    perfettoController.onBecomingActive();
  }

  Future<void> _initForServiceConnection() async {
    await serviceConnection.timelineStreamManager.setDefaultTimelineStreams();

    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (!serviceConnection.serviceManager.connectedState.value.connected) {
        _pollingTimer?.cancel();
        _timelinePollingRateLimiter?.dispose();
      }
    });

    // Load available timeline events.
    await forceRefresh();

    _timelinePollingRateLimiter = RateLimiter(
      _timelinePollingRateLimit,
      _pullPerfettoVmTimeline,
    );

    // Poll for new timeline events.
    // We are polling here instead of listening to the timeline event stream
    // because the event stream is sending out of order and duplicate events.
    // See https://github.com/dart-lang/sdk/issues/46605.
    _pollingTimer = Timer.periodic(_timelinePollingInterval, (_) {
      _timelinePollingRateLimiter!.scheduleRequest();
    });
  }

  Future<void> _pullPerfettoVmTimeline({bool isInitialPull = false}) async {
    final service = serviceConnection.serviceManager.service;
    if (service == null) return;
    final currentVmTime = await service.getVMTimelineMicros();
    debugTraceCallback(
      () => _log.info(
        '[_pullPerfettoVmTimeline] time range: '
        '($_nextPollStartMicros - ${currentVmTime.timestamp})',
      ),
    );

    late PerfettoTimeline rawPerfettoTimeline;
    if (preferences.performance.includeCpuSamplesInTimeline.value) {
      await debugTimeAsync(
        () async => rawPerfettoTimeline =
            await service.getPerfettoVMTimelineWithCpuSamplesWrapper(
          timeOriginMicros: _nextPollStartMicros,
          timeExtentMicros: currentVmTime.timestamp! - _nextPollStartMicros,
        ),
        debugName: 'VmService.getPerfettoVMTimelineWithCpuSamples',
      );
    } else {
      await debugTimeAsync(
        () async => rawPerfettoTimeline = await service.getPerfettoVMTimeline(
          timeOriginMicros: _nextPollStartMicros,
          timeExtentMicros: currentVmTime.timestamp! - _nextPollStartMicros,
        ),
        debugName: 'VmService.getPerfettoVMTimeline',
      );
    }
    _nextPollStartMicros = currentVmTime.timestamp! + 1;

    Uint8List? traceBinary;
    debugTimeSync(
      () => traceBinary = base64Decode(rawPerfettoTimeline.trace!),
      debugName: 'base64Decode perfetto trace',
    );
    _updatePerfettoTrace(traceBinary!, logWarning: isInitialPull);
  }

  void _updatePerfettoTrace(Uint8List traceBinary, {bool logWarning = true}) {
    final decodedTrace =
        _prepareForTraceProcessing(traceBinary, logWarning: logWarning);

    if (fullPerfettoTrace == null) {
      debugTraceCallback(
        () => _log.info(
          '[_updatePerfettoTrace] setting initial perfetto trace',
        ),
      );
      fullPerfettoTrace = decodedTrace ?? _traceFromBinary(traceBinary);
    } else {
      debugTraceCallback(
        () => _log.info(
          '[_updatePerfettoTrace] merging perfetto trace with new buffer',
        ),
      );
      debugTimeSync(
        () => fullPerfettoTrace!.mergeFromBuffer(traceBinary),
        debugName: 'perfettoTrace.mergeFromBuffer',
      );
    }
  }

  Trace? _prepareForTraceProcessing(
    Uint8List traceBinary, {
    bool logWarning = true,
  }) {
    if (!_isFlutterAppHelper()) {
      debugTraceCallback(
        () => _log
            .info('[_prepareTraceForProcessing] not a flutter app, returning.'),
      );
      return null;
    }

    final trace = _traceFromBinary(traceBinary);
    final newTrackDescriptors = <PerfettoTrackDescriptorEvent>[];
    for (final packet in trace.packet) {
      if (packet.hasTrackDescriptor()) {
        final trackDescriptor =
            PerfettoTrackDescriptorEvent(packet.trackDescriptor);
        final added = _trackDescriptors.add(trackDescriptor);
        if (added) {
          newTrackDescriptors.add(trackDescriptor);
        }
      }
      if (packet.hasTrackEvent()) {
        final trackEvent = PerfettoTrackEvent.fromPacket(packet);
        _unprocessedTrackEvents.add(trackEvent);
      }
    }
    updateTrackIds(newTrackDescriptors, logWarning: logWarning);
    return trace;
  }

  void updateTrackIds(
    List<PerfettoTrackDescriptorEvent> trackDescriptorEvents, {
    bool logWarning = false,
  }) {
    if (!_isFlutterAppHelper()) return;

    Int64? uiTrackId;
    Int64? rasterTrackId;
    Int64? flutterTestTrackId;
    for (final track in trackDescriptorEvents) {
      final name = track.name;
      final id = track.id;
      // Android: "1.ui (12652)"
      // iOS: "io.flutter.1.ui (12652)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.ui (225695)"
      if (name.contains(uiThreadSuffix)) {
        uiTrackId = id;
      }

      // Android: "1.raster (12651)"
      // iOS: "io.flutter.1.raster (12651)"
      // Linux, Windows, Dream (g3): "io.flutter.raster (12651)"
      // MacOS: Does not exist
      // Also look for .gpu here for older versions of Flutter.
      // TODO(kenz): remove check for .gpu name in April 2021.
      if (name.contains(rasterThreadSuffix) || name.contains(gpuThreadSuffix)) {
        rasterTrackId = id;
      }

      // Android: "1.platform (22585)"
      // iOS: "io.flutter.1.platform (22585)"
      // MacOS, Linux, Windows, Dream (g3): "io.flutter.platform (22596)"
      // DO NOT include Flutter test thread "io.flutter.test..platform"
      if (name.contains(platformThreadSuffix) &&
          !name.contains(flutterTestThreadSuffix)) {
        // MacOS and Flutter apps with platform views do not have a .gpu
        // thread. In these cases, the "Raster" events will come on the
        // .platform thread instead.
        rasterTrackId ??= id;
      }

      if (name.contains(flutterTestThreadSuffix)) {
        flutterTestTrackId = id;
      }
    }

    if (flutterTestTrackId != null &&
        uiTrackId == null &&
        rasterTrackId == null) {
      // If the connected app is a Flutter tester device, the UI and Raster
      // events will come on the same thread / track.
      uiTrackId = flutterTestTrackId;
      rasterTrackId = flutterTestTrackId;
    }

    if (logWarning && (uiTrackId == null || rasterTrackId == null)) {
      _log.info(
        'Could not find UI track and / or Raster track from names: '
        '${trackDescriptorEvents.map((e) => e.name)}',
      );
    }
    perfettoController.processor.primeTrackIds(
      ui: uiTrackId,
      raster: rasterTrackId,
    );
  }

  Future<void> forceRefresh() async {
    debugTraceCallback(() => _log.info('[forceRefresh]'));
    await _pullPerfettoVmTimeline();
    processTrackEvents();
    await loadPerfettoTrace();
  }

  void processTrackEvents() {
    if (!_isFlutterAppHelper()) {
      debugTraceCallback(
        () => _log.info('[processTrackEvents] not a flutter app, returning.'),
      );
      return;
    }

    final eventCount = _unprocessedTrackEvents.length;
    debugTraceCallback(
      () => _log.info('[processTrackEvents] count: $eventCount'),
    );

    // Process track events and time the operation for analytics.
    ga.timeSync(
      gac.performance,
      gac.PerformanceEvents.perfettoModeTraceEventProcessingTime.nameOverride!,
      syncOperation: () => perfettoController.processor
          .processTrackEvents(_unprocessedTrackEvents),
      screenMetricsProvider: () =>
          PerformanceScreenMetrics(traceEventCount: eventCount),
    );
    _unprocessedTrackEvents.clear();
  }

  Future<void> loadPerfettoTrace() async {
    debugTraceCallback(() => _log.info('[loadPerfettoTrace] updating viewer'));
    await perfettoController.loadTrace(fullPerfettoTrace ?? Trace());
  }

  @override
  Future<void> handleSelectedFrame(FlutterFrame frame) async {
    debugTraceCallback(
      () => _log.info('[handleSelectedFrame]\n${frame.toStringVerbose()}'),
    );
    await _perfettoSelectFrame(frame);
  }

  Future<void> _perfettoSelectFrame(FlutterFrame frame) async {
    // No need to process events again if we are in offline mode - we have
    // already processed all the available data.
    if (!offlineController.offlineMode.value) {
      bool hasProcessedTimelineEventsForFrame =
          perfettoController.processor.hasProcessedEventsForFrame(frame.id);
      if (!hasProcessedTimelineEventsForFrame) {
        debugTraceCallback(
          () => _log.info(
            '[_perfettoSelectFrame] no events for frame. Process all events.',
          ),
        );
        processTrackEvents();
      }

      hasProcessedTimelineEventsForFrame =
          perfettoController.processor.hasProcessedEventsForFrame(frame.id);
      if (!hasProcessedTimelineEventsForFrame) {
        debugTraceCallback(
          () => _log.info(
            '[_perfettoSelectFrame] events still not processed. Force refresh.',
          ),
        );

        final frameBeforeEarliestTimelineData =
            firstWellFormedFlutterFrameId != null &&
                frame.id < firstWellFormedFlutterFrameId!;
        if (!frameBeforeEarliestTimelineData) {
          // If we still have not processed the timeline events for this frame,
          // try forcing a refresh. Only do this if it is possible to fetch the
          // timeline data for the [frame] we are trying to scroll to.
          await _workTracker.track(forceRefresh);

          // TODO(kenz): it would be best if we can avoid making subsequent
          // calls to [forceRefresh] when we hit this case.
          if (firstWellFormedFlutterFrameId == null) {
            // At this point, we still have not processed any timeline events
            // for Flutter frames, which means we will never have access to the
            // timeline events for this [frame].
            pushNoTimelineEventsAvailableWarning();
          }
        }
      }
    }

    // TODO(https://github.com/flutter/flutter/issues/144782): remove once this
    // issue is fixed. Due to this bug, we sometimes have very large and
    // innacurate values for frame time durations. When this occurs, fallback
    // to using the time range from the frame's timeline events. This heuristic
    // assumes that there will never be a frame that took longer than 100
    // seconds, which is still pretty high.
    var timeRange = frame.timeFromFrameTiming;
    const frameTimeHeuristic = 100;
    if (timeRange.duration.inSeconds > frameTimeHeuristic) {
      timeRange = frame.timeFromEventFlows;
    }

    perfettoController.scrollToTimeRange(timeRange);
  }

  void addTimelineEvent(FlutterTimelineEvent event) {
    assert(_isFlutterAppHelper());
    _maybeAddEventToUnassignedFrame(event);
  }

  void _maybeAddEventToUnassignedFrame(FlutterTimelineEvent event) {
    final frameNumber = event.flutterFrameNumber;
    if (frameNumber != null && (event.isUiEvent || event.isRasterEvent)) {
      if (performanceController.flutterFramesController
          .hasUnassignedFlutterFrame(frameNumber)) {
        firstWellFormedFlutterFrameId = math.min(
          firstWellFormedFlutterFrameId ?? frameNumber,
          frameNumber,
        );
        performanceController.flutterFramesController.assignEventToFrame(
          frameNumber,
          event,
        );
      } else {
        final unassignedEventsForFrame =
            _unassignedFlutterTimelineEvents.putIfAbsent(
          frameNumber,
          () => FrameTimelineEventData(),
        );
        unassignedEventsForFrame.setEventFlow(event: event, setTimeData: false);
      }
    }
  }

  void maybeAddUnassignedEventsToFrame(FlutterFrame frame) {
    _maybeAddUnassignedEventToFrame(frame, TimelineEventType.ui);
    _maybeAddUnassignedEventToFrame(frame, TimelineEventType.raster);
    if (frame.isWellFormed) {
      _unassignedFlutterTimelineEvents.remove(frame.id);
    }
  }

  void _maybeAddUnassignedEventToFrame(
    FlutterFrame frame,
    TimelineEventType type,
  ) {
    final event = _unassignedFlutterTimelineEvents[frame.id]?.eventByType(type);
    if (event != null) {
      frame.setEventFlow(event);
    }
  }

  bool _isFlutterAppHelper() {
    final offlineData = performanceController.offlinePerformanceData;
    return offlineController.offlineMode.value
        ? offlineData != null && offlineData.frames.isNotEmpty
        : serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
            false;
  }

  @override
  Future<void> setOfflineData(OfflinePerformanceData offlineData) async {
    if (offlineData.perfettoTraceBinary != null) {
      _updatePerfettoTrace(offlineData.perfettoTraceBinary!);
    }
    processTrackEvents();
    await loadPerfettoTrace();

    if (offlineData.selectedFrame != null) {
      perfettoController
          .scrollToTimeRange(offlineData.selectedFrame!.timeFromFrameTiming);
    }
  }

  @override
  Future<void> clearData() async {
    _unprocessedTrackEvents.clear();
    fullPerfettoTrace = Trace();
    _trackDescriptors.clear();
    _unassignedFlutterTimelineEvents.clear();

    _workTracker.clear();
    _status.value = EventsControllerStatus.empty;
    await perfettoController.clear();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timelinePollingRateLimiter?.dispose();
    perfettoController.dispose();
    super.dispose();
  }
}

Trace _traceFromBinary(Uint8List traceBinary) {
  late Trace trace;
  debugTimeSync(
    () => trace = Trace.fromBuffer(traceBinary),
    debugName: 'Trace.fromBuffer',
  );
  return trace;
}
