// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/allowed_error.dart';
import '../globals.dart';
import '../http/http_request_data.dart';
import '../http/http_service.dart';
import '../ui/filter.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'network_model.dart';
import 'network_service.dart';

class NetworkController
    with
        SearchControllerMixin<NetworkRequest>,
        FilterControllerMixin<NetworkRequest> {
  NetworkController() {
    _networkService = NetworkService(this);
  }

  static const methodFilterId = 'network-method-filter';

  static const statusFilterId = 'network-status-filter';

  static const typeFilterId = 'network-type-filter';

  final _filterArgs = {
    methodFilterId: FilterArgument(keys: ['method', 'm']),
    statusFilterId: FilterArgument(keys: ['status', 's']),
    typeFilterId: FilterArgument(keys: ['type', 't']),
  };

  @override
  Map<String, FilterArgument> get filterArgs => _filterArgs;

  /// Notifies that new Network requests have been processed.
  ValueListenable<NetworkRequests> get requests => _requests;

  final _requests = ValueNotifier<NetworkRequests>(NetworkRequests());

  ValueListenable<NetworkRequest> get selectedRequest => _selectedRequest;

  final _selectedRequest = ValueNotifier<NetworkRequest>(null);

  /// Notifies that the timeline is currently being recorded.
  ValueListenable<bool> get recordingNotifier => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  @visibleForTesting
  NetworkService get networkService => _networkService;
  NetworkService _networkService;

  /// The timeline timestamps are relative to when the VM started.
  ///
  /// This value is equal to
  /// `DateTime.now().microsecondsSinceEpoch - _profileStartMicros` when
  /// recording is started is used to calculate the correct wall-time for
  /// timeline events.
  int _timelineMicrosOffset;

  /// The last timestamp at which HTTP and Socket information was refreshed.
  int lastRefreshMicros = 0;

  Timer _pollingTimer;

  @visibleForTesting
  bool get isPolling => _pollingTimer != null;

  void selectRequest(NetworkRequest selection) {
    _selectedRequest.value = selection;
  }

  @visibleForTesting
  NetworkRequests processNetworkTrafficHelper(
    Timeline timeline,
    List<SocketStatistic> sockets,
    int timelineMicrosOffset, {
    @required List<NetworkRequest> currentValues,
    @required List<HttpRequestData> invalidRequests,
    @required Map<String, HttpRequestData> outstandingRequestsMap,
  }) {
    final events = timeline.traceEvents;
    // Group all HTTP timeline events with the same ID.
    final httpEvents = <String, List<Map<String, Object>>>{};
    final httpRequestIdToResponseId = <String, String>{};
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

      // Any HTTP event with a specified 'parentId' is the response event of
      // another request (the request with 'id' = 'parentId'). Store the
      // relationship in [httpRequestIdToResponseId].
      final parentId = json['args']['parentId'];
      if (parentId != null) {
        httpRequestIdToResponseId[parentId] = id;
      }
      httpEvents.putIfAbsent(id, () => []).add(json);
    }

    // Build our list of network requests from the collected events.
    for (final request in httpEvents.entries) {
      final requestId = request.key;

      // Do not handle response events - they are handled as part of the request
      if (httpRequestIdToResponseId.values.contains(requestId)) continue;

      final responseId = httpRequestIdToResponseId[requestId];
      final responseEvents = <Map<String, Object>>[];
      if (responseId != null) {
        responseEvents.addAll(httpEvents[responseId] ?? []);
      }

      final requestData = HttpRequestData.fromTimeline(
        timelineMicrosBase: timelineMicrosOffset,
        requestEvents: request.value,
        responseEvents: responseEvents,
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
      if (requestData.isValid) {
        currentValues.add(requestData);
      } else {
        // Request is complete but missing some information
        invalidRequests.add(requestData);
      }
    }

    // [currentValues] contains all the current requests we have in the
    // profiler, which will contain web socket requests if they exist. The new
    // [sockets] may contain web sockets with the same ids as ones we already
    // have, so we remove the current web sockets and replace them with updated
    // data.
    currentValues.removeWhere((value) => value is WebSocket);
    for (final socket in sockets) {
      final webSocket = WebSocket(socket, timelineMicrosOffset);
      // If we have updated data for the selected web socket, update the value.
      if (_selectedRequest.value is WebSocket &&
          (_selectedRequest.value as WebSocket).id == webSocket.id) {
        _selectedRequest.value = webSocket;
      }
      currentValues.add(webSocket);
    }

    return NetworkRequests(
      requests: currentValues,
      invalidHttpRequests: invalidRequests,
      outstandingHttpRequests: outstandingRequestsMap,
    );
  }

  void processNetworkTraffic({
    @required Timeline timeline,
    @required List<SocketStatistic> sockets,
  }) {
    // Trigger refresh.
    _requests.value = processNetworkTrafficHelper(
      timeline,
      sockets,
      _timelineMicrosOffset,
      currentValues: List.from(requests.value.requests),
      invalidRequests: [],
      outstandingRequestsMap: Map.from(requests.value.outstandingHttpRequests),
    );
    _updateData();
    _updateSelection();
  }

  void _updatePollingState(bool recording) {
    if (recording) {
      _pollingTimer ??= Timer.periodic(
        // TODO(kenz): look into improving performance by caching more data.
        // Polling less frequently helps performance.
        const Duration(milliseconds: 2000),
        (_) => _networkService.refreshNetworkData(),
      );
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> startRecording() async {
    await _startRecording(alreadyRecordingHttp: await recordingHttpTraffic());
  }

  /// Enables network traffic recording on all isolates and starts polling for
  /// HTTP and Socket information.
  ///
  /// If `alreadyRecording` is true, the last refresh time will be assumed to
  /// be the beginning of the process (time 0).
  Future<void> _startRecording({
    bool alreadyRecordingHttp = false,
  }) async {
    // Cancel existing polling timer before starting recording.
    _updatePollingState(false);

    final timestamp = await _networkService.updateLastRefreshTime(
      alreadyRecordingHttp: alreadyRecordingHttp,
    );

    // Determine the offset that we'll use to calculate the approximate
    // wall-time a request was made. This won't be 100% accurate, but it should
    // easily be within a second.
    _timelineMicrosOffset = DateTime.now().microsecondsSinceEpoch - timestamp;
    // TODO(jacobr): add an intermediate manager class to track which flags are
    // set. We are setting more flags than we probably need to here but setting
    // fewer flags risks breaking functionality on the timeline view that
    // assumes that all flags are set.
    await allowedError(
        serviceManager.service.setVMTimelineFlags(['GC', 'Dart', 'Embedder']));

    // TODO(kenz): only call these if http logging and socket profiling are not
    // already enabled. Listen to service manager streams for this info.
    await Future.wait([
      HttpService.toggleHttpRequestLogging(true),
      networkService.toggleSocketProfiling(true),
    ]);
    togglePolling(true);
  }

  void stopRecording() {
    togglePolling(false);
  }

  void togglePolling(bool state) {
    // Do not toggle the vm recording state - just enable or disable polling.
    _updatePollingState(state);
    _recordingNotifier.value = state;
  }

  Future<bool> recordingHttpTraffic() async {
    bool enabled = true;
    await serviceManager.service.forEachIsolate(
      (isolate) async {
        final httpFuture =
            serviceManager.service.httpEnableTimelineLogging(isolate.id);
        // The above call won't complete immediately if the isolate is paused,
        // so give up waiting after 500ms.
        final state = await timeout(httpFuture, 500);
        if (state == null || !state.enabled) {
          enabled = false;
        }
      },
    );
    return enabled;
  }

  /// Clears the previously collected HTTP timeline events, clears the socket
  /// profile from the vm, and resets the last refresh timestamp to the current
  /// time.
  Future<void> clear() async {
    await _networkService.clearData();
    _requests.value = NetworkRequests();
    resetFilter();
    _updateData();
    _updateSelection();
  }

  void _updateData() {
    filterData(activeFilter.value);
    refreshSearchMatches();
  }

  void _updateSelection() {
    final selected = _selectedRequest.value;
    if (selected != null) {
      final requests = filteredData.value;
      if (!requests.contains(selected)) {
        _selectedRequest.value = null;
      }
    }
  }

  @override
  List<NetworkRequest> matchesForSearch(String search) {
    if (search == null || search.isEmpty) return [];
    final matches = <NetworkRequest>[];
    final caseInsensitiveSearch = search.toLowerCase();

    final currentRequests = filteredData.value;
    for (final request in currentRequests) {
      if (request.uri.toLowerCase().contains(caseInsensitiveSearch)) {
        matches.add(request);
      }
    }
    return matches;
  }

  @override
  void filterData(QueryFilter filter) {
    if (filter == null) {
      filteredData.value = List.from(_requests.value.requests);
    } else {
      filteredData.value = _requests.value.requests.where((NetworkRequest r) {
        final methodArg = filter.filterArguments[methodFilterId];
        if (methodArg != null &&
            !methodArg.matchesValue(r.method.toLowerCase())) {
          return false;
        }

        final statusArg = filter.filterArguments[statusFilterId];
        if (statusArg != null &&
            !statusArg.matchesValue(r.status?.toLowerCase())) {
          return false;
        }

        final typeArg = filter.filterArguments[typeFilterId];
        if (typeArg != null && !typeArg.matchesValue(r.type.toLowerCase())) {
          return false;
        }

        if (filter.substrings.isNotEmpty) {
          for (final substring in filter.substrings) {
            final caseInsensitiveSubstring = substring.toLowerCase();
            final matchesUri =
                r.uri.toLowerCase().contains(caseInsensitiveSubstring);
            if (matchesUri) return true;

            final matchesMethod =
                r.method.toLowerCase().contains(caseInsensitiveSubstring);
            if (matchesMethod) return true;

            final matchesStatus =
                r.status?.toLowerCase()?.contains(caseInsensitiveSubstring) ??
                    false;
            if (matchesStatus) return true;

            final matchesType =
                r.type.toLowerCase().contains(caseInsensitiveSubstring);
            if (matchesType) return true;
          }
          return false;
        }
        return true;
      }).toList();
    }
    activeFilter.value = filter;
  }
}
