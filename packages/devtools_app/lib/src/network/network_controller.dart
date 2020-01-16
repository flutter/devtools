// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../ui/fake_flutter/fake_flutter.dart';
import 'http_request_data.dart';
import 'network_service.dart';

class NetworkController {
  NetworkController() {
    _networkService = NetworkService(this);
  }

  /// Notifies that new HTTP requests have been processed.
  ValueListenable get requestsNotifier => _httpRequestsNotifier;
  final _httpRequestsNotifier = ValueNotifier<HttpRequests>(HttpRequests());

  /// Notifies that the timeline is currently being recorded.
  ValueListenable get recordingNotifier => httpRecordingNotifier;
  final httpRecordingNotifier = ValueNotifier<bool>(false);

  NetworkService _networkService;

  // The timeline timestamps are relative to when the VM started. This value is
  // equal to `DateTime.now().microsecondsSinceEpoch - _profileStartMicros` when
  // recording is started is used to calculate the correct wall-time for
  // timeline events.
  int _timelineMicrosOffset;
  int lastProfileRefreshMicros = 0;

  Timer _pollingTimer;

  @visibleForTesting
  static HttpRequests processHttpTimelineEventsHelper(
      Timeline timeline,
      int timelineMicrosOffset,
      List<HttpRequestData> currentValues,
      Map<String, HttpRequestData> outstandingRequestsMap) {
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
        httpEvents.putIfAbsent(id, () => []).add(json);
      }
    }

    // Build our list of network requests from the collected events.
    for (final request in httpEvents.entries) {
      final requestId = request.key;
      final requestData = HttpRequestData.fromTimeline(
        timelineMicrosOffset,
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
    return HttpRequests(
      requests: currentValues,
      outstandingRequests: outstandingRequestsMap,
    );
  }

  void processHttpTimelineEvents(Timeline timeline) {
    final currentValues = List<HttpRequestData>.from(
      _httpRequestsNotifier.value.requests,
    );
    final outstandingRequestsMap = Map<String, HttpRequestData>.from(
      _httpRequestsNotifier.value.outstandingRequests,
    );
    // Trigger refresh.
    _httpRequestsNotifier.value = processHttpTimelineEventsHelper(
        timeline, _timelineMicrosOffset, currentValues, outstandingRequestsMap);
  }

  Future<void> _setHttpTimelineRecording(bool state) async {
    assert(state == !httpRecordingNotifier.value);
    await _networkService.enableHttpRequestLogging(state);

    if (state) {
      // Start polling once we've enabled logging.
      assert(_pollingTimer == null);
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _networkService.refreshHttpRequests(),
      );
    } else {
      // Stop polling once we've disabled logging.
      assert(_pollingTimer != null);
      _pollingTimer.cancel();
      _pollingTimer = null;
    }
  }

  /// Enables HTTP request recording on all isolates and starts polling.
  ///
  /// If `alreadyRecording` is true, the last refresh time will be assumed to
  /// be the beginning of the process (time 0).
  Future<void> startRecording({
    bool alreadyRecording = false,
  }) async {
    final timestamp = await _networkService.updateLastRefreshTime(
        alreadyRecording: alreadyRecording);

    // Determine the offset that we'll use to calculate the approximate
    // wall-time a request was made. This won't be 100% accurate, but it should
    // easily be within a second.
    _timelineMicrosOffset = DateTime.now().microsecondsSinceEpoch - timestamp;

    await _setHttpTimelineRecording(true);
  }

  /// Pauses the output of HTTP request information to the timeline.
  ///
  /// May result in some incomplete timeline events.
  Future<void> pauseRecording() async => await _setHttpTimelineRecording(false);

  /// Checks to see if HTTP requests are currently being output. If so, recording
  /// is automatically started upon initialization.
  Future<void> initialize() async =>
      await _networkService.initializeRecordingState();

  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Clears the previously collected HTTP timeline events and resets the last
  /// refresh timestamp to the current time.
  Future<void> clear() async {
    await _networkService.updateLastRefreshTime();
    _httpRequestsNotifier.value = HttpRequests();
  }
}
