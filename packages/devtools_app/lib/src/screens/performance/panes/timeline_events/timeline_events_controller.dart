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
import '../../../../shared/primitives/byte_utils.dart';
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
  refreshing,
  ready,
}

class TimelineEventsController extends PerformanceFeatureController
    with AutoDisposeControllerMixin {
  TimelineEventsController(super.performanceController) {
    perfettoController = createPerfettoController(performanceController, this);
    addAutoDisposeListener(_refreshWorkTracker.active, () {
      final active = _refreshWorkTracker.active.value;
      if (active) {
        _status.value = EventsControllerStatus.refreshing;
      } else {
        _status.value = EventsControllerStatus.ready;
      }
    });
    traceRingBuffer = Uint8ListRingBuffer(maxSizeBytes: _traceRingBufferSize);
  }

  static const uiThreadSuffix = '.ui';
  static const rasterThreadSuffix = '.raster';
  static const gpuThreadSuffix = '.gpu';
  static const platformThreadSuffix = '.platform';
  static const flutterTestThreadSuffix = '.flutter.test..platform';
  static final _refreshWorkTrackerDelay =
      const Duration(milliseconds: 500).inMicroseconds;

  /// Controller that contains business logic for the Perfetto trace viewer.
  late final PerfettoController perfettoController;

  /// The complete Perfetto timeline that DevTools has received from the VM.
  ///
  /// This returns the merged value of all the traces in [traceRingBuffer],
  /// which is periodically trimmed to preserve memory in DevTools.
  Uint8List get fullPerfettoTrace => traceRingBuffer.merged;

  /// A ring buffer containing all the Perfetto trace binaries that we have
  /// received from the VM.
  ///
  /// This ring buffer is built up by polling every [_timelinePollingInterval]
  /// and fetching new Perfetto timeline data from the VM.
  ///
  /// We use a ring buffer for this data so that the earliest entries will be
  /// removed when the total size of this queue exceeds [_traceRingBufferSize].
  /// This prevents the Performance page from causing DevTools to OOM.
  ///
  /// The bytes contained in this ring buffer are stored until the Perfetto
  /// viewer is refreshed, at which point [fullPerfettoTrace] will be called to
  /// merge all of this data into a single trace binary for the Perfetto UI to
  /// consume.
  @visibleForTesting
  late final Uint8ListRingBuffer traceRingBuffer;

  /// Size limit in GB for [traceRingBuffer] that determines when traces should
  /// be removed from the queue.
  final _traceRingBufferSize =
      convertBytes(1, from: ByteUnit.gb, to: ByteUnit.byte).round();

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

  final _refreshWorkTracker = FutureWorkTracker();

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
        () async {
          await ga.timeAsync(
            gac.performance,
            gac.PerformanceEvents.getPerfettoVMTimelineWithCpuSamplesTime.name,
            asyncOperation: () async {
              rawPerfettoTimeline =
                  await service.getPerfettoVMTimelineWithCpuSamplesWrapper(
                timeOriginMicros: _nextPollStartMicros,
                timeExtentMicros:
                    currentVmTime.timestamp! - _nextPollStartMicros,
              );
            },
          );
        },
        debugName: 'VmService.getPerfettoVMTimelineWithCpuSamples',
      );
    } else {
      await debugTimeAsync(
        () async {
          await ga.timeAsync(
            gac.performance,
            gac.PerformanceEvents.getPerfettoVMTimelineTime.name,
            asyncOperation: () async {
              rawPerfettoTimeline = await service.getPerfettoVMTimeline(
                timeOriginMicros: _nextPollStartMicros,
                timeExtentMicros:
                    currentVmTime.timestamp! - _nextPollStartMicros,
              );
            },
          );
        },
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
    _prepareForTraceProcessing(traceBinary, logWarning: logWarning);
    traceRingBuffer.addData(traceBinary);
  }

  void _prepareForTraceProcessing(
    Uint8List traceBinary, {
    bool logWarning = true,
  }) {
    if (!_isFlutterAppHelper()) {
      debugTraceCallback(
        () => _log
            .info('[_prepareTraceForProcessing] not a flutter app, returning.'),
      );
      return;
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
    await _refreshWorkTracker.track(
      _forceRefresh,
      // Await a short delay so that we can insert the refreshing message
      // overlay on top of the Perfetto UI.
      delayMicros: _refreshWorkTrackerDelay,
    );
  }

  Future<void> _forceRefresh() async {
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
    await perfettoController.loadTrace(fullPerfettoTrace);
  }

  @override
  Future<void> handleSelectedFrame(FlutterFrame frame) async {
    debugTraceCallback(
      () => _log.info('[handleSelectedFrame]\n${frame.toStringVerbose()}'),
    );

    void processMoreEventsOrExitHelper({
      required FutureOr<void> Function() onProcessMore,
    }) async {
      final hasProcessedTimelineEventsForFrame =
          perfettoController.processor.hasProcessedEventsForFrame(frame.id);
      if (!hasProcessedTimelineEventsForFrame) {
        final timelineEventsUnavailable =
            perfettoController.processor.frameIsBeforeTimelineData(frame.id);
        if (timelineEventsUnavailable) {
          pushNoTimelineEventsAvailableWarning();
          return;
        }
        await onProcessMore();
      }
    }

    // No need to process events again if we are in offline mode - we have
    // already processed all the available data.
    if (!offlineController.offlineMode.value) {
      processMoreEventsOrExitHelper(
        onProcessMore: () {
          debugTraceCallback(
            () => _log.info(
              '[handleSelectedFrame] no events for frame. Process all events.',
            ),
          );
          processTrackEvents();
        },
      );

      // Call this a second time to see if events for this frame have been
      // processed after calling the lighter weight [processTrackEvents] method,
      // which processes all unprocessed events that we have collected.
      processMoreEventsOrExitHelper(
        onProcessMore: () async {
          // If we still have not processed the events for this frame, force a
          // refresh to pull the latest data from the VM.
          debugTraceCallback(
            () => _log.info(
              '[handleSelectedFrame] events still not processed. Force refresh.',
            ),
          );
          await forceRefresh();

          final hasProcessedTimelineEventsForFrame =
              perfettoController.processor.hasProcessedEventsForFrame(frame.id);
          if (!hasProcessedTimelineEventsForFrame) {
            // At this point, we still have not processed any timeline events
            // for this Flutter frame, which means we will never have access to
            // the timeline events for [frame].
            pushNoTimelineEventsAvailableWarning();
          }
        },
      );
    }

    perfettoController.scrollToTimeRange(frame.timeFromFrameTiming);
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
    traceRingBuffer.clear();
    _trackDescriptors.clear();
    _unassignedFlutterTimelineEvents.clear();

    _refreshWorkTracker.clear();
    _status.value = EventsControllerStatus.empty;
    await perfettoController.clear();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _timelinePollingRateLimiter?.dispose();
    perfettoController.dispose();
    _refreshWorkTracker.clear();
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
