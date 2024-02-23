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
import '../../shared/utils.dart';
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

enum _NetworkTrafficType {
  http,
  socket,
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
  Map<String, QueryFilterArgument<NetworkRequest>> createQueryFilterArgs() => {
        methodFilterId: QueryFilterArgument<NetworkRequest>(
          keys: ['method', 'm'],
          dataValueProvider: (request) => request.method,
          substringMatch: false,
        ),
        statusFilterId: QueryFilterArgument<NetworkRequest>(
          keys: ['status', 's'],
          dataValueProvider: (request) => request.status,
          substringMatch: false,
        ),
        typeFilterId: QueryFilterArgument<NetworkRequest>(
          keys: ['type', 't'],
          dataValueProvider: (request) => request.type,
          substringMatch: false,
        ),
      };

  /// Notifies that new Network requests have been processed.
  ValueListenable<List<NetworkRequest>> get requests => _currentNetworkRequests;

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

  /// The last time at which HTTP information was refreshed.
  DateTime lastHttpDataRefreshTime = DateTime.fromMicrosecondsSinceEpoch(0);

  /// The last timestamp at which Socket information was refreshed.
  ///
  /// This timestamp is on the monotonic clock used by the timeline.
  int lastSocketDataRefreshMicros = 0;

  DebounceTimer? _pollingTimer;

  @visibleForTesting
  bool get isPolling => _pollingTimer != null;

  void _processHttpProfileRequests({
    required List<HttpProfileRequest> newOrUpdatedHttpRequests,
    required CurrentNetworkRequests currentRequests,
  }) {
    currentRequests.updateOrAdd(newOrUpdatedHttpRequests);
    _filterAndRefreshSearchMatches();
  }

  @visibleForTesting
  void processNetworkTrafficHelper(
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
      newOrUpdatedHttpRequests: httpRequests!,
      currentRequests: currentRequests,
    );
  }

  void processNetworkTraffic({
    required List<SocketStatistic> sockets,
    required List<HttpProfileRequest>? httpRequests,
  }) {
    // Trigger refresh.
    // we reassign this every time which
    processNetworkTrafficHelper(
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
      _pollingTimer ??= DebounceTimer.periodic(
        // TODO(kenz): look into improving performance by caching more data.
        // Polling less frequently helps performance.
        const Duration(milliseconds: 2000),
        (_) async => _networkService.refreshNetworkData(),
      );
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> startRecording() async {
    await _startRecording(
      alreadyRecordingHttp:
          await _recordingNetworkTraffic(type: _NetworkTrafficType.http),
      alreadyRecordingSocketData:
          await _recordingNetworkTraffic(type: _NetworkTrafficType.socket),
    );
  }

  /// Enables network traffic recording on all isolates and starts polling for
  /// HTTP and Socket information.
  ///
  /// If `alreadyRecording` is true, the last refresh time will be assumed to
  /// be the beginning of the process (time 0).
  Future<void> _startRecording({
    bool alreadyRecordingHttp = false,
    bool alreadyRecordingSocketData = false,
  }) async {
    // Cancel existing polling timer before starting recording.
    _updatePollingState(false);

    _networkService.updateLastHttpDataRefreshTime(
      alreadyRecordingHttp: alreadyRecordingHttp,
    );
    final timestamp = await _networkService.updateLastSocketDataRefreshTime(
      alreadyRecordingSocketData: alreadyRecordingSocketData,
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

  Future<bool> _recordingNetworkTraffic({
    required _NetworkTrafficType type,
  }) async {
    bool enabled = true;
    final service = serviceConnection.serviceManager.service!;
    await service.forEachIsolate(
      (isolate) async {
        final future = switch (type) {
          _NetworkTrafficType.http =>
            service.httpEnableTimelineLoggingWrapper(isolate.id!),
          _NetworkTrafficType.socket =>
            service.socketProfilingEnabledWrapper(isolate.id!),
        };
        // The above call won't complete immediately if the isolate is paused,
        // so give up waiting after 500ms.
        final state = await timeout(future, 500);
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
      _currentNetworkRequests.value.forEach(_checkForError);
      filteredData
        ..clear()
        ..addAll(_currentNetworkRequests.value);
      return;
    }
    filteredData
      ..clear()
      ..addAll(
        _currentNetworkRequests.value.where((NetworkRequest r) {
          final filteredOutByQueryFilterArgument = queryFilter
              .filterArguments.values
              .any((argument) => !argument.matchesValue(r));
          if (filteredOutByQueryFilterArgument) return false;

          if (queryFilter.substringExpressions.isNotEmpty) {
            for (final substring in queryFilter.substringExpressions) {
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
class CurrentNetworkRequests extends ValueNotifier<List<NetworkRequest>> {
  CurrentNetworkRequests({required this.onRequestDataChange}) : super([]);

  ValueListenable<List<NetworkRequest>> get requests =>
      this; // todo: remove this and just let callers use .value
  final _requestsById = <String, NetworkRequest>{};

  /// Triggered whenever the request's data changes on its own.
  VoidCallback onRequestDataChange;

  NetworkRequest? getRequest(String id) => _requestsById[id];

  /// Update or add the [request] to the [requests] depending on whether or not
  /// its [request.id] already exists in the list.
  ///
  void updateOrAdd(List<HttpProfileRequest> requests) {
    for (int i = 0; i < requests.length; i++) {
      final request = requests[i];
      _updateOrAdd(request);
    }
    notifyListeners();
  }

  void _updateOrAdd(HttpProfileRequest request) {
    final wrapped = DartIOHttpRequestData(
      request,
      requestFullDataFromVmService: false,
    );
    if (!_requestsById.containsKey(request.id)) {
      _requestsById[wrapped.id] = wrapped;
      value.add(wrapped);
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
        final existingRequest = _requestsById[webSocket.id];
        if (existingRequest is WebSocket) {
          existingRequest.update(webSocket);
        } else {
          // If we override an entry that is not a Websocket then that means
          // the ids of the requestMapping entries may collide with other types
          // of requests.
          assert(existingRequest is WebSocket);
        }
      } else {
        value.add(webSocket);
        // The new [sockets] may contain web sockets with the same ids as ones we
        // already have, so we remove the current web sockets and replace them with
        // updated data.
        _requestsById[webSocket.id] = webSocket;
      }
    }
    notifyListeners();
    onRequestDataChange();
  }

  void clear() {
    _requestsById.clear();
    value = [];
    notifyListeners();
  }
}
