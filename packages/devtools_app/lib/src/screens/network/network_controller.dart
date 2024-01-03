// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/config_specific/logger/allowed_error.dart';
import '../../shared/globals.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/http/http_service.dart' as http_service;
import '../../shared/primitives/utils.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import 'network_model.dart';
import 'network_screen.dart';
import 'network_service.dart';

/// Different types of Network Response which can be used to visualise response
/// on Response tab
enum NetworkResponseViewType {
  auto,
  text,
  json;

  @override
  String toString() {
    return switch (this) {
      NetworkResponseViewType.json => 'Json',
      NetworkResponseViewType.text => 'Text',
      _ => 'Auto',
    };
  }
}

class NetworkController extends DisposableController
    with
        SearchControllerMixin<NetworkRequest>,
        FilterControllerMixin<NetworkRequest>,
        AutoDisposeControllerMixin {
  NetworkController() {
    _networkService = NetworkService(this);
    _currentNetworkRequests = CurrentNetworkRequests(
      onRequestDataChange: _filterAndRefreshSearchMatches,
    );
    subscribeToFilterChanges();
  }

  static const methodFilterId = 'network-method-filter';

  static const statusFilterId = 'network-status-filter';

  static const typeFilterId = 'network-type-filter';

  @override
  Map<String, QueryFilterArgument> createQueryFilterArgs() => {
        methodFilterId: QueryFilterArgument(keys: ['method', 'm']),
        statusFilterId: QueryFilterArgument(keys: ['status', 's']),
        typeFilterId: QueryFilterArgument(keys: ['type', 't']),
      };

  /// Notifies that new Network requests have been processed.
  ValueListenable<NetworkRequests> get requests => _requests;

  final _requests = ValueNotifier<NetworkRequests>(NetworkRequests());

  /// Notifies that current response type has been changed
  ValueListenable<NetworkResponseViewType> get currentResponseViewType =>
      _currentResponseViewType;

  final _currentResponseViewType =
      ValueNotifier<NetworkResponseViewType>(NetworkResponseViewType.auto);

  /// Change current response type
  set setResponseViewType(NetworkResponseViewType type) =>
      _currentResponseViewType.value = type;

  /// Reset drop down to initial state when current network request is changed
  void resetDropDown() {
    _currentResponseViewType.value = NetworkResponseViewType.auto;
  }

  final selectedRequest = ValueNotifier<NetworkRequest?>(null);
  late CurrentNetworkRequests _currentNetworkRequests;

  /// Notifies that the timeline is currently being recorded.
  ValueListenable<bool> get recordingNotifier => _recordingNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);

  @visibleForTesting
  NetworkService get networkService => _networkService;
  late NetworkService _networkService;

  /// The timeline timestamps are relative to when the VM started.
  ///
  /// This value is equal to
  /// `DateTime.now().microsecondsSinceEpoch - _profileStartMicros` when
  /// recording is started is used to calculate the correct wall-time for
  /// timeline events.
  late int _timelineMicrosOffset;

  /// The last timestamp at which HTTP and Socket information was refreshed.
  int lastRefreshMicros = 0;

  Timer? _pollingTimer;

  @visibleForTesting
  bool get isPolling => _pollingTimer != null;

  void _processHttpProfileRequests({
    required int timelineMicrosOffset,
    required List<HttpProfileRequest> newOrUpdatedHttpRequests,
    required CurrentNetworkRequests currentRequests,
  }) {
    for (final request in newOrUpdatedHttpRequests) {
      currentRequests.updateOrAdd(request, timelineMicrosOffset);
    }
  }

  @visibleForTesting
  NetworkRequests processNetworkTrafficHelper(
    List<SocketStatistic> sockets,
    List<HttpProfileRequest>? httpRequests,
    int timelineMicrosOffset, {
    required CurrentNetworkRequests currentRequests,
  }) {
    currentRequests.updateWebSocketRequests(sockets, timelineMicrosOffset);

    // If we have updated data for the selected web socket, we need to update
    // the value.
    final currentSelectedRequestId = selectedRequest.value?.id;
    if (currentSelectedRequestId != null) {
      selectedRequest.value =
          currentRequests.getRequest(currentSelectedRequestId);
    }

    _processHttpProfileRequests(
      timelineMicrosOffset: timelineMicrosOffset,
      newOrUpdatedHttpRequests: httpRequests!,
      currentRequests: currentRequests,
    );

    return NetworkRequests(
      requests: currentRequests.requests,
    );
  }

  void processNetworkTraffic({
    required List<SocketStatistic> sockets,
    required List<HttpProfileRequest>? httpRequests,
  }) {
    // Trigger refresh.
    _requests.value = processNetworkTrafficHelper(
      sockets,
      httpRequests,
      _timelineMicrosOffset,
      currentRequests: _currentNetworkRequests,
    );
    _filterAndRefreshSearchMatches();
    _updateSelection();
  }

  void _updatePollingState(bool recording) {
    if (recording) {
      _pollingTimer ??= Timer.periodic(
        // TODO(kenz): look into improving performance by caching more data.
        // Polling less frequently helps performance.
        const Duration(milliseconds: 2000),
        (_) => unawaited(_networkService.refreshNetworkData()),
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
      serviceConnection.serviceManager.service!
          .setVMTimelineFlags(['GC', 'Dart', 'Embedder']),
    );

    // TODO(kenz): only call these if http logging and socket profiling are not
    // already enabled. Listen to service manager streams for this info.
    await Future.wait([
      http_service.toggleHttpRequestLogging(true),
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
    final service = serviceConnection.serviceManager.service!;
    await service.forEachIsolate(
      (isolate) async {
        final httpFuture =
            service.httpEnableTimelineLoggingWrapper(isolate.id!);
        // The above call won't complete immediately if the isolate is paused,
        // so give up waiting after 500ms.
        final state = await timeout(httpFuture, 500);
        if (state?.enabled != true) {
          enabled = false;
        }
      },
    );
    return enabled;
  }

  /// Clears the HTTP profile and socket profile from the vm, and resets the
  /// last refresh timestamp to the current time.
  Future<void> clear() async {
    await _networkService.clearData();
    _requests.value = NetworkRequests();
    _currentNetworkRequests.clear();
    resetFilter();
    _filterAndRefreshSearchMatches();
    _updateSelection();
  }

  void _filterAndRefreshSearchMatches() {
    filterData(activeFilter.value);
    refreshSearchMatches();
  }

  void _updateSelection() {
    final selected = selectedRequest.value;
    if (selected != null) {
      final requests = filteredData.value;
      if (!requests.contains(selected)) {
        selectedRequest.value = null;
      }
    }
  }

  @override
  Iterable<NetworkRequest> get currentDataToSearchThrough => filteredData.value;

  @override
  void filterData(Filter<NetworkRequest> filter) {
    super.filterData(filter);
    serviceConnection.errorBadgeManager.clearErrors(NetworkScreen.id);
    final queryFilter = filter.queryFilter;
    if (queryFilter.isEmpty) {
      _requests.value.requests.forEach(_checkForError);
      filteredData
        ..clear()
        ..addAll(_requests.value.requests);
      return;
    }
    filteredData
      ..clear()
      ..addAll(
        _requests.value.requests.where((NetworkRequest r) {
          final methodArg = queryFilter.filterArguments[methodFilterId];
          if (methodArg != null && !methodArg.matchesValue(r.method)) {
            return false;
          }

          final statusArg = queryFilter.filterArguments[statusFilterId];
          if (statusArg != null && !statusArg.matchesValue(r.status)) {
            return false;
          }

          final typeArg = queryFilter.filterArguments[typeFilterId];
          if (typeArg != null && !typeArg.matchesValue(r.type)) {
            return false;
          }

          if (queryFilter.substrings.isNotEmpty) {
            for (final substring in queryFilter.substrings) {
              bool matches(String? stringToMatch) {
                if (stringToMatch?.caseInsensitiveContains(substring) == true) {
                  _checkForError(r);
                  return true;
                }
                return false;
              }

              if (matches(r.uri)) return true;
              if (matches(r.method)) return true;
              if (matches(r.status)) return true;
              if (matches(r.type)) return true;
            }
            return false;
          }
          _checkForError(r);
          return true;
        }).toList(),
      );
  }

  void _checkForError(NetworkRequest r) {
    if (r.didFail) {
      serviceConnection.errorBadgeManager.incrementBadgeCount(NetworkScreen.id);
    }
  }
}

/// Class for managing the set of all current websocket requests, and
/// http profile requests.
class CurrentNetworkRequests {
  CurrentNetworkRequests({required this.onRequestDataChange});

  List<NetworkRequest> get requests => _requestsById.values.toList();
  final _requestsById = <String, NetworkRequest>{};

  /// Triggered whenever the request's data changes on its own.
  VoidCallback onRequestDataChange;

  NetworkRequest? getRequest(String id) => _requestsById[id];

  /// Update or add the [request] to the [requests] depending on whether or not
  /// its [request.id] already exists in the list.
  ///
  void updateOrAdd(
    HttpProfileRequest request,
    int timelineMicrosOffset,
  ) {
    final wrapped = DartIOHttpRequestData(
      timelineMicrosOffset,
      request,
      requestFullDataFromVmService: false,
    );
    if (!_requestsById.containsKey(request.id)) {
      wrapped.requestUpdatedNotifier.addListener(() => onRequestDataChange());
      _requestsById[wrapped.id] = wrapped;
    } else {
      // If we override an entry that is not a DartIOHttpRequestData then that means
      // the ids of the requestMapping entries may collide with other types
      // of requests.
      assert(_requestsById[request.id] is DartIOHttpRequestData);
      (_requestsById[request.id] as DartIOHttpRequestData).merge(wrapped);
    }
  }

  void updateWebSocketRequests(
    List<SocketStatistic> sockets,
    int timelineMicrosOffset,
  ) {
    for (final socket in sockets) {
      final webSocket = WebSocket(socket, timelineMicrosOffset);

      if (_requestsById.containsKey(webSocket.id)) {
        // If we override an entry that is not a Websocket then that means
        // the ids of the requestMapping entries may collide with other types
        // of requests.
        assert(_requestsById[webSocket.id] is WebSocket);
      }

      // The new [sockets] may contain web sockets with the same ids as ones we
      // already have, so we remove the current web sockets and replace them with
      // updated data.
      _requestsById[webSocket.id] = webSocket;
      onRequestDataChange();
    }
  }

  void clear() {
    _requestsById.clear();
  }
}
