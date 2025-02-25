// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/config_specific/logger/allowed_error.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/http/http_service.dart' as http_service;
import '../../shared/offline/offline_data.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils/utils.dart';
import 'har_network_data.dart';
import 'network_model.dart';
import 'network_screen.dart';
import 'network_service.dart';
import 'offline_network_data.dart';

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

enum _NetworkTrafficType { http, socket }

/// Screen controller for the Network screen.
///
/// This controller can be accessed from anywhere in DevTools, as long as it was
/// first registered, by
/// calling `screenControllers.lookup<NetworkController>()`.
///
/// The controller lifecycle is managed by the [ScreenControllers] class. The
/// `init` method is called lazily upon the first controller access from
/// `screenControllers`. The `dispose` method is called by `screenControllers`
/// when DevTools is destroying a set of DevTools screen controllers.
class NetworkController extends DevToolsScreenController
    with
        SearchControllerMixin<NetworkRequest>,
        FilterControllerMixin<NetworkRequest>,
        OfflineScreenControllerMixin,
        AutoDisposeControllerMixin {
  List<DartIOHttpRequestData>? _httpRequests;

  Future<String?> exportAsHarFile() async {
    await fetchFullDataBeforeExport();
    _httpRequests =
        filteredData.value.whereType<DartIOHttpRequestData>().toList();

    if (_httpRequests.isNullOrEmpty) {
      debugPrint('No valid request data to export');
      return '';
    }

    try {
      // Build the HAR object
      final har = HarNetworkData(_httpRequests!);
      return ExportController().downloadFile(
        json.encode(har.toJson()),
        type: ExportFileType.har,
      );
    } catch (e) {
      debugPrint('Exception in export $e');
    }
    return null;
  }

  static const methodFilterId = 'network-method-filter';

  static const statusFilterId = 'network-status-filter';

  static const typeFilterId = 'network-type-filter';

  @override
  Map<String, QueryFilterArgument<NetworkRequest>> createQueryFilterArgs() => {
    methodFilterId: QueryFilterArgument<NetworkRequest>(
      keys: ['method', 'm'],
      exampleUsages: ['m:get', '-m:put,patch'],
      dataValueProvider: (request) => request.method,
      substringMatch: false,
    ),
    statusFilterId: QueryFilterArgument<NetworkRequest>(
      keys: ['status', 's'],
      exampleUsages: ['s:200', '-s:404'],
      dataValueProvider: (request) => request.status,
      substringMatch: false,
    ),
    typeFilterId: QueryFilterArgument<NetworkRequest>(
      keys: ['type', 't'],
      exampleUsages: ['t:json', '-t:text'],
      dataValueProvider: (request) => request.type,
      substringMatch: false,
    ),
  };

  @override
  ValueNotifier<String>? get filterTagNotifier => preferences.network.filterTag;

  /// Notifies that new Network requests have been processed.
  ValueListenable<List<NetworkRequest>> get requests => _currentNetworkRequests;

  /// Notifies that current response type has been changed
  ValueListenable<NetworkResponseViewType> get currentResponseViewType =>
      _currentResponseViewType;

  final _currentResponseViewType = ValueNotifier<NetworkResponseViewType>(
    NetworkResponseViewType.auto,
  );

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

  final networkService = NetworkService();

  /// The timeline timestamps are relative to when the VM started.
  ///
  /// This value is equal to
  /// `DateTime.now().microsecondsSinceEpoch - _profileStartMicros` when
  /// recording is started is used to calculate the correct wall-time for
  /// timeline events.
  late int _timelineMicrosOffset;

  /// The last timestamp at which Socket information was refreshed.
  ///
  /// This timestamp is on the monotonic clock used by the timeline.
  int lastSocketDataRefreshMicros = 0;

  DebounceTimer? _pollingTimer;

  @visibleForTesting
  bool get isPolling => _pollingTimer != null;

  static const _pollingDuration = Duration(milliseconds: 2000);

  @override
  void init() {
    super.init();
    _currentNetworkRequests = CurrentNetworkRequests();
    _initHelper();
    addAutoDisposeListener(
      _currentNetworkRequests,
      _filterAndRefreshSearchMatches,
    );
    initFilterController();
  }

  @override
  void dispose() {
    // Cancel and dispose the polling timer before disposing anything else.
    _pollingTimer?.dispose();
    _pollingTimer = null;
    _currentResponseViewType.dispose();
    selectedRequest.dispose();
    _recordingNotifier.dispose();
    _currentNetworkRequests.dispose();
    super.dispose();
  }

  void _initHelper() async {
    if (offlineDataController.showingOfflineData.value) {
      await maybeLoadOfflineData(
        NetworkScreen.id,
        createData: (json) => OfflineNetworkData.fromJson(json),
        // This ignore is used because the 'data' parameter can have a dynamic type,
        // which cannot be explicitly typed here due to its dependency on JSON parsing.
        // ignore: avoid_dynamic_calls
        shouldLoad: (data) => !data.isEmpty,
        loadData: (data) => loadOfflineData(data),
      );
    }
    if (serviceConnection.serviceManager.connectedState.value.connected) {
      await startRecording();
    }
  }

  void loadOfflineData(OfflineNetworkData offlineData) {
    final httpProfileData =
        offlineData.httpRequestData.mapToHttpProfileRequests;
    final socketStatsData = offlineData.socketData.mapToSocketStatistics;

    _currentNetworkRequests
      ..clear()
      ..updateOrAddAll(
        requests: httpProfileData,
        sockets: socketStatsData,
        timelineMicrosOffset: offlineData.timelineMicrosOffset ?? 0,
      );
    _filterAndRefreshSearchMatches();

    // If a selectedRequestId is available, select it in offline mode.
    if (offlineData.selectedRequestId != null) {
      final selected = _currentNetworkRequests.getRequest(
        offlineData.selectedRequestId ?? '',
      );
      if (selected != null) {
        selectedRequest.value = selected;
        resetDropDown();
      }
    }
  }

  @visibleForTesting
  void processNetworkTrafficHelper(
    List<SocketStatistic> sockets,
    List<HttpProfileRequest>? httpRequests,
    int timelineMicrosOffset, {
    required CurrentNetworkRequests currentRequests,
  }) {
    currentRequests.updateOrAddAll(
      requests: httpRequests!,
      sockets: sockets,
      timelineMicrosOffset: timelineMicrosOffset,
    );

    // If we have updated data for the selected socket, we need to update
    // the value.
    final currentSelectedRequestId = selectedRequest.value?.id;
    if (currentSelectedRequestId != null) {
      selectedRequest.value = currentRequests.getRequest(
        currentSelectedRequestId,
      );
    }
  }

  void processNetworkTraffic({
    required List<SocketStatistic> sockets,
    required List<HttpProfileRequest>? httpRequests,
  }) {
    // Trigger refresh.
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
        _pollingDuration,
        networkService.refreshNetworkData,
      );
    } else {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  Future<void> startRecording() async {
    await _startRecording(
      alreadyRecordingHttp: await _recordingNetworkTraffic(
        type: _NetworkTrafficType.http,
      ),
      alreadyRecordingSocketData: await _recordingNetworkTraffic(
        type: _NetworkTrafficType.socket,
      ),
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

    networkService.updateLastHttpDataRefreshTime(
      alreadyRecordingHttp: alreadyRecordingHttp,
    );
    final timestamp = await networkService.updateLastSocketDataRefreshTime(
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
      serviceConnection.serviceManager.service!.setVMTimelineFlags([
        'GC',
        'Dart',
        'Embedder',
      ]),
    );

    // TODO(kenz): only call these if http logging and socket profiling are not
    // already enabled. Listen to service manager streams for this info.
    await [
      http_service.toggleHttpRequestLogging(true),
      networkService.toggleSocketProfiling(true),
    ].wait;
    await togglePolling(true);
  }

  Future<void> stopRecording() async {
    if (!disposed) {
      await togglePolling(false);
    }
  }

  Future<void> togglePolling(bool state) async {
    if (state) {
      // Update the last refresh time so that the next polling instance
      // will only fetch values since we started recording.
      await updateLastRefreshTime();
    }

    // Do not toggle the vm recording state - just enable or disable polling.
    _updatePollingState(state);
    _recordingNotifier.value = state;
  }

  /// Updates the last refresh time of the socket and http data refresh times.
  ///
  /// This will ensure that future fetches for http and socket requests will at
  /// most fetch requests since [updateLastRefreshTime] was called.
  Future<void> updateLastRefreshTime() async {
    networkService.updateLastHttpDataRefreshTime();
    await networkService.updateLastSocketDataRefreshTime();
  }

  Future<bool> _recordingNetworkTraffic({
    required _NetworkTrafficType type,
  }) async {
    bool enabled = true;
    final service = serviceConnection.serviceManager.service!;
    await service.forEachIsolate((isolate) async {
      final future = switch (type) {
        _NetworkTrafficType.http => service.httpEnableTimelineLoggingWrapper(
          isolate.id!,
        ),
        _NetworkTrafficType.socket => service.socketProfilingEnabledWrapper(
          isolate.id!,
        ),
      };
      // The above call won't complete immediately if the isolate is paused,
      // so give up waiting after 500ms.
      final state = await timeout(future, 500);
      if (state?.enabled != true) {
        enabled = false;
      }
    });
    return enabled;
  }

  /// Clears the HTTP profile and socket profile from the vm, and resets the
  /// last refresh timestamp to the current time.
  Future<void> clear() async {
    await networkService.clearData();
    _currentNetworkRequests.clear();
    _filterAndRefreshSearchMatches();
    _updateSelection();
  }

  @override
  void setActiveFilter({
    String? query,
    SettingFilters<NetworkRequest>? settingFilters,
  }) {
    super.setActiveFilter(query: query, settingFilters: settingFilters);
    _filterAndRefreshSearchMatches();
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
              .filterArguments
              .values
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

  @override
  OfflineScreenData prepareOfflineScreenData() {
    final httpRequestData = <DartIOHttpRequestData>[];
    final socketData = <Socket>[];
    for (final request in _currentNetworkRequests.value) {
      if (request is DartIOHttpRequestData) {
        httpRequestData.add(request);
      } else if (request is Socket) {
        socketData.add(request);
      }
    }

    final offlineData = OfflineNetworkData(
      httpRequestData: httpRequestData,
      socketData: socketData,
      selectedRequestId: selectedRequest.value?.id,
      timelineMicrosOffset: _timelineMicrosOffset,
    );

    return OfflineScreenData(
      screenId: NetworkScreen.id,
      data: offlineData.toJson(),
    );
  }

  Future<void> fetchFullDataBeforeExport() =>
      filteredData.value
          .whereType<DartIOHttpRequestData>()
          .map((item) => item.getFullRequestData())
          .wait;
}

/// Class for managing the set of all current sockets, and
/// http profile requests.
class CurrentNetworkRequests extends ValueNotifier<List<NetworkRequest>> {
  CurrentNetworkRequests() : super([]);

  final _requestsById = <String, NetworkRequest>{};

  NetworkRequest? getRequest(String id) => _requestsById[id];

  /// Update or add all [requests] and [sockets] to the current requests.
  ///
  /// If the entry already exists then it will be modified in place, otherwise
  /// a new [HttpProfileRequest] will be added to the end of the requests lists.
  ///
  /// [notifyListeners] will only be called once all [requests] and [sockets]
  /// have be updated or added.
  void updateOrAddAll({
    required List<HttpProfileRequest> requests,
    required List<SocketStatistic> sockets,
    required int timelineMicrosOffset,
  }) {
    _updateOrAddRequests(requests);
    _updateSocketProfiles(sockets, timelineMicrosOffset);
    notifyListeners();
  }

  /// Update or add the [request] to the [requests] depending on whether or not
  /// its [request.id] already exists in the list.
  ///
  void _updateOrAddRequests(List<HttpProfileRequest> requests) {
    for (int i = 0; i < requests.length; i++) {
      final request = requests[i];
      _updateOrAddRequest(request);
    }
  }

  void _updateOrAddRequest(HttpProfileRequest request) {
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

  void _updateSocketProfiles(
    List<SocketStatistic> sockets,
    int timelineMicrosOffset,
  ) {
    for (final socketStats in sockets) {
      final socket = Socket(socketStats, timelineMicrosOffset);

      if (_requestsById.containsKey(socket.id)) {
        final existingRequest = _requestsById[socket.id];
        if (existingRequest is Socket) {
          existingRequest.update(socket);
        } else {
          // If we override an entry that is not a Socket then that means
          // the ids of the requestMapping entries may collide with other types
          // of requests.
          assert(existingRequest is Socket);
        }
      } else {
        value.add(socket);
        // The new [sockets] may contain sockets with the same ids as ones we
        // already have, so we remove the current sockets and replace them with
        // updated data.
        _requestsById[socket.id] = socket;
      }
    }
  }

  void clear() {
    _requestsById.clear();
    value = [];
    notifyListeners();
  }
}
