// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import 'http_request_data.dart';

class NetworkController {
  /// Notifies that new HTTP requests have been processed.
  ValueListenable get requestsNotifier => _httpRequestsNotifier;
  final _httpRequestsNotifier = ValueNotifier<HttpRequests>(HttpRequests());

  /// Notifies that the timeline is currently being recorded.
  ValueListenable get recordingNotifier => _httpRecordingNotifier;
  final _httpRecordingNotifier = ValueNotifier<bool>(false);

  // The timeline timestamps are relative to when the VM started. This value is
  // equal to `DateTime.now().microsecondsSinceEpoch - _profileStartMicros` when
  // recording is started is used to calculate the correct wall-time for
  // timeline events.
  int _timelineMicrosOffset;
  int _lastProfileRefreshMicros = 0;

  void _processHttpTimelineEvents(Timeline timeline) {
    final currentValues = _httpRequestsNotifier.value.requests;
    final outstandingRequestsMap =
        _httpRequestsNotifier.value.outstandingRequests;
    final events = timeline.traceEvents;
    final httpEventIds = <String>{};
    // Perform initial pass to find the IDs for the HTTP timeline events.
    for (final TimelineEvent event in events) {
      final json = event.toJson();
      final id = json['id'];
      if (id == null) {
        continue;
      }
      // The start event for HTTP contains a filter key which we can use.
      // Note: only HTTP client requests are currently logged to the timeline.
      if ((!json['args'].containsKey('filterKey') ||
              json['args']['filterKey'] != 'HTTP/client') &&
          !outstandingRequestsMap.containsKey(id)) {
        continue;
      }
      httpEventIds.add(id);
    }

    // Group all HTTP timeline events with the same ID.
    final httpEvents = <String, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final json = event.toJson();
      final id = json['id'];
      if (id == null) {
        continue;
      }
      if (httpEventIds.contains(id)) {
        if (!httpEvents.containsKey(id)) {
          httpEvents[id] = [];
        }
        httpEvents.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(json);
      }
    }

    // Build our list of network requests from the collected events.
    for (final request in httpEvents.entries) {
      final requestId = request.key;
      final requestData = HttpRequestData.fromTimeline(
        _timelineMicrosOffset,
        request.value,
      );

      // If there's a new event which matches a request that was previously in
      // flight, update the associated HttpRequestData.
      if (outstandingRequestsMap.containsKey(requestId)) {
        final outstandingRequest = outstandingRequestsMap[requestId];
        outstandingRequest.merge(requestData);
        if (!outstandingRequest.inProgress) {
          outstandingRequestsMap.remove(requestId);
        }
        continue;
      } else if (requestData.inProgress) {
        outstandingRequestsMap.putIfAbsent(requestId, () => requestData);
      }
      currentValues.add(requestData);
    }
    // Trigger refresh.
    _httpRequestsNotifier.value = HttpRequests(
      requests: currentValues,
      outstandingRequests: outstandingRequestsMap,
    );
  }

  void _startPolling() {
    // TODO(bkonyi): provide a way to cancel this polling loop.
    Future<void>.delayed(const Duration(milliseconds: 1000)).then(
      (_) {
        if (_httpRecordingNotifier.value) {
          refreshRequests();
          _startPolling();
        }
      },
    );
  }

  Future<void> _forEachIsolate(Future Function(IsolateRef) callback) async {
    final vm = await serviceManager.service.getVM();
    final futures = <Future>[];
    for (final isolate in vm.isolates) {
      futures.add(callback(isolate));
    }
    await Future.wait(futures);
  }

  Future<void> _setHttpTimelineRecording(bool state) async {
    await _forEachIsolate(
      (isolate) async {
        final future = serviceManager.service
            .setHttpEnableTimelineLogging(isolate.id, state);
        // If the isolate is paused the request above will never complete.
        await Future.any(
          [
            future,
            Future.delayed(const Duration(milliseconds: 500)),
          ],
        );
      },
    );
    _httpRecordingNotifier.value = state;
  }

  /// Force refreshes the HTTP requests logged to the timeline.
  Future<void> refreshRequests() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    final timeline = await serviceManager.service.getVMTimeline(
        timeOriginMicros: _lastProfileRefreshMicros,
        timeExtentMicros: timestamp.timestamp - _lastProfileRefreshMicros);
    _lastProfileRefreshMicros = timestamp.timestamp;
    _processHttpTimelineEvents(timeline);
  }

  /// Enables HTTP request recording on all isolates and starts polling.
  ///
  /// If `alreadyRecording` is true, the last refresh time will be assumed to
  /// be the beginning of the process (time 0).
  Future<void> startRecording({
    bool alreadyRecording = false,
  }) async {
    // Set the current timeline time as the time of the last refresh.
    final timestamp = await serviceManager.service.getVMTimelineMicros();

    if (!alreadyRecording) {
      // Only include HTTP requests issued after the current time.
      _lastProfileRefreshMicros = timestamp.timestamp;
    }

    // Determine the offset that we'll use to calculate the approximate
    // wall-time a request was made. This won't be 100% accurate, but it should
    // easily be within a second.
    _timelineMicrosOffset =
        DateTime.now().microsecondsSinceEpoch - timestamp.timestamp;

    await resumeRecording();
  }

  /// Pauses the output of HTTP request information to the timeline.
  ///
  /// May result in some incomplete timeline events.
  Future<void> pauseRecording() async => await _setHttpTimelineRecording(false);

  /// Resumes recording without resetting the last refresh timestamp.
  Future<void> resumeRecording() async {
    await _setHttpTimelineRecording(true);
    _startPolling();
  }

  /// Checks to see if HTTP requests are currently being output. If so, recording
  /// is automatically started upon initialization.
  Future<void> initialize() async {
    bool enabled = false;
    await _forEachIsolate(
      (isolate) async {
        final future =
            serviceManager.service.getHttpEnableTimelineLogging(isolate.id);
        // The above call won't complete if the isolate is paused.
        final state = await Future.any<HttpTimelineLoggingState>(
          [
            future,
            Future.delayed(
              const Duration(milliseconds: 500),
              () => null,
            ),
          ],
        );
        if (state != null && state.enabled) {
          enabled = true;
        }
      },
    );
    if (enabled && !_httpRecordingNotifier.value) {
      await startRecording(alreadyRecording: true);
      _httpRecordingNotifier.value = enabled;
    } else if (!enabled && _httpRecordingNotifier.value) {
      // TODO(bkonyi): do we want to pause recording if no isolates are currently
      // writing timeline events?
      await pauseRecording();
      _httpRecordingNotifier.value = enabled;
    }
  }

  /// Clears the previously collected HTTP timeline events and resets the last
  /// refresh timestamp to the current time.
  Future<void> clear() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    _lastProfileRefreshMicros = timestamp.timestamp;
    _httpRequestsNotifier.value = HttpRequests();
  }
}
