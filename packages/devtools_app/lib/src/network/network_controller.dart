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
import 'network_screen.dart';
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

  void _processTimeline({
    @required Timeline timeline,
    @required int timelineMicrosOffset,
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

      final requestData = TimelineHttpRequestData.fromTimeline(
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
  }

  void _processHttpProfileRequests({
    @required List<HttpProfileRequest> httpRequests,
    @required List<NetworkRequest> currentValues,
    @required Map<String, HttpRequestData> outstandingRequestsMap,
  }) {
    for (final request in httpRequests) {
      final wrapped = DartIOHttpRequestData(
        _timelineMicrosOffset,
        request,
      );
      final id = request.id.toString();
      if (outstandingRequestsMap.containsKey(id)) {
        outstandingRequestsMap[id].merge(wrapped);
        if (!outstandingRequestsMap[id].inProgress) {
          final data =
              outstandingRequestsMap.remove(id) as DartIOHttpRequestData;
          data.getFullRequestData().then((value) => _updateData());
        }
        continue;
      } else if (wrapped.inProgress) {
        outstandingRequestsMap.putIfAbsent(id, () => wrapped);
      } else {
        // If the response has completed, send a request for body data.
        wrapped.getFullRequestData().then((value) => _updateData());
      }
      currentValues.add(wrapped);
    }
  }

  @visibleForTesting
  NetworkRequests processNetworkTrafficHelper(
    Timeline timeline,
    List<SocketStatistic> sockets,
    List<HttpProfileRequest> httpRequests,
    int timelineMicrosOffset, {
    @required List<NetworkRequest> currentValues,
    @required List<HttpRequestData> invalidRequests,
    @required Map<String, HttpRequestData> outstandingRequestsMap,
  }) {
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

    if (timeline != null) {
      _processTimeline(
        timeline: timeline,
        timelineMicrosOffset: timelineMicrosOffset,
        currentValues: currentValues,
        invalidRequests: invalidRequests,
        outstandingRequestsMap: outstandingRequestsMap,
      );
    } else {
      _processHttpProfileRequests(
        httpRequests: httpRequests,
        currentValues: currentValues,
        outstandingRequestsMap: outstandingRequestsMap,
      );
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
    @required List<HttpProfileRequest> httpRequests,
  }) {
    // Trigger refresh.
    _requests.value = processNetworkTrafficHelper(
      timeline,
      sockets,
      httpRequests,
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
        // TODO(kenz): use the value of this property in the network requests
        // table to improve performance. This will require some refactoring of
        // FlatTable.
        request.isSearchMatch = true;
      } else {
        request.isSearchMatch = false;
      }
    }
    return matches;
  }

  @override
  void filterData(QueryFilter filter) {
    serviceManager.errorBadgeManager.clearErrors(NetworkScreen.id);
    if (filter == null) {
      _requests.value.requests.forEach(_checkForError);
      filteredData
        ..clear()
        ..addAll(_requests.value.requests);
    } else {
      filteredData
        ..clear()
        ..addAll(_requests.value.requests.where((NetworkRequest r) {
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
              bool matches(String stringToMatch) {
                if (stringToMatch
                    .toLowerCase()
                    .contains(caseInsensitiveSubstring)) {
                  _checkForError(r);
                  return true;
                }
                return false;
              }

              if (matches(r.uri)) return true;
              if (matches(r.method)) return true;
              if (matches(r.status ?? '')) return true;
              if (matches(r.type)) return true;
            }
            return false;
          }
          _checkForError(r);
          return true;
        }).toList());
    }
    activeFilter.value = filter;
  }

  void _checkForError(NetworkRequest r) {
    if (r.didFail) {
      serviceManager.errorBadgeManager.incrementBadgeCount(NetworkScreen.id);
    }
  }
}
