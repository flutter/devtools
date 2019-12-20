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
  // recording is started is used to calculate the correct time for timeline
  // events.
  int _timelineMicrosOffset;
  int _profileStartMicros = 0;

  void _processHttpTimelineEvents(Timeline timeline) {
    final currentValues = _httpRequestsNotifier.value.requests;
    final outstandingRequestsMap = _httpRequestsNotifier.value.outstanding;
    final events = timeline.traceEvents;
    final httpEventIds = <String>{};
    // Perform initial pass to find the IDs for the HTTP timeline events.
    for (final TimelineEvent event in events) {
      final json = event.toJson();
      final id = json['id'];
      if (id == null) {
        continue;
      }
      if ((!json['args'].containsKey('filterKey') ||
              json['args']['filterKey'] != 'HTTP/client') &&
          !outstandingRequestsMap.containsKey(id)) {
        continue;
      }
      httpEventIds.add(id);
    }

    print('Event count: ${httpEventIds.length}');

    // Group all HTTP timeline events with the same ID.
    final Map<String, List<Map>> httpEvents = {};
    for (final event in events) {
      final json = event.toJson();
      final id = json['id'];
      if (json['id'] == null) {
        continue;
      }
      if (httpEventIds.contains(id)) {
        if (!httpEvents.containsKey(id)) {
          httpEvents[id] = [];
        }
        httpEvents[id].add(json);
      }
    }

    // Build our list of network requests from the collected events.
    for (final request in httpEvents.entries) {
      final requestId = request.key;
      final requestData =
          HttpRequestData.fromTimeline(_timelineMicrosOffset, request.value);

      // If there's a new event which matches a request that was previously in
      // flight, update the associated HttpRequestData.
      if (outstandingRequestsMap.containsKey(requestId) &&
          !requestData.inProgress) {
        // TODO(bkonyi): don't assume this is an endEvent
        final outstandingRequest = outstandingRequestsMap[requestId];
        outstandingRequest.endEvent = requestData.endEvent;
        outstandingRequestsMap.remove(requestId);
        continue;
      } else if (requestData.inProgress) {
        outstandingRequestsMap.putIfAbsent(requestId, () => requestData);
      }
      currentValues.add(requestData);
    }
    // Trigger refresh.
    _httpRequestsNotifier.value.requests = currentValues;
    // TODO(bkonyi): figure out better way to trigger notification.
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    _httpRequestsNotifier.notifyListeners();
  }

  void _startPolling() {
    Future<void>.delayed(const Duration(milliseconds: 1000)).then((_) {
      if (_httpRecordingNotifier.value) {
        refreshRequests();
        _startPolling();
      }
    });
  }

  // TODO(bkonyi): get state at startup
  Future<void> _setHttpTimelineRecording(bool state) async {
    _httpRecordingNotifier.value = state;
  }

  Future<void> refreshRequests() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    final timeline = await serviceManager.service.getVMTimeline(
        timeOriginMicros: _profileStartMicros,
        timeExtentMicros: timestamp.timestamp - _profileStartMicros);
    _profileStartMicros = timestamp.timestamp;
    _processHttpTimelineEvents(timeline);
  }

  Future<void> startRecording() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    _profileStartMicros = timestamp.timestamp;
    _timelineMicrosOffset =
        DateTime.now().microsecondsSinceEpoch - _profileStartMicros;
    await _setHttpTimelineRecording(true);
    _startPolling();
  }

  Future<void> pauseRecording() async {
    await _setHttpTimelineRecording(false);
  }

  Future<void> clear() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    _profileStartMicros = timestamp.timestamp;
    _httpRequestsNotifier.value.clear();
  }
}
