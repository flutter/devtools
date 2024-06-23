// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../devtools_app.dart';
import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/config_specific/logger/allowed_error.dart';
import '../../shared/http/http_service.dart' as http_service;
import 'network_service.dart';

final _exportController = ExportController();
List<DartIOHttpRequestData>? httpRequests;

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
        OfflineScreenControllerMixin,
        AutoDisposeControllerMixin {
  NetworkController() {
    _networkService = NetworkService(this);
    _currentNetworkRequests = CurrentNetworkRequests();
    addAutoDisposeListener(
      _currentNetworkRequests,
      _filterAndRefreshSearchMatches,
    );
    subscribeToFilterChanges();
  }

  String? exportAsHarFile() {
    httpRequests =
        filteredData.value.whereType<DartIOHttpRequestData>().toList();

    if (httpRequests!.isEmpty) {
      debugPrint('No valid request data to export');
      return '';
    }

    try {
      if (httpRequests!.isNotEmpty) {
        final har = {
          'log': {
            'version': '1.2',
            'creator': {
              'name': 'flutter_tool',
              'version': '0.0.2',
            },
            'pages': [
              {
                'startedDateTime': httpRequests?.first.startTimestamp
                    .toUtc()
                    .toIso8601String(),
                'id': 'page_0',
                'title': 'FlutterCapture',
                'pageTimings': {
                  'onContentLoad': -1,
                  'onLoad': -1,
                },
              },
            ],
            'entries': httpRequests
                ?.map(
                  (e) => {
                    'pageref': 'page_0',
                    'startedDateTime':
                        e.startTimestamp.toUtc().toIso8601String(),
                    'time': e.duration?.inMilliseconds,
                    'request': {
                      'method': e.method.toUpperCase(),
                      'url': e.uri.toString(),
                      'httpVersion': 'HTTP/1.1',
                      'cookies': e.requestCookies
                          .map(
                            (e) => {
                              'name': e.name,
                              'value': e.value,
                              'path': e.path,
                              'domain': e.domain,
                              'expires': e.expires?.toUtc().toIso8601String(),
                              'httpOnly': e.httpOnly,
                              'secure': e.secure,
                            },
                          )
                          .toList(),
                      'headers': e.requestHeaders?.entries.map((h) {
                        var value = h.value;
                        if (value is List) {
                          value = value.first;
                        }
                        return {
                          'name': h.key,
                          'value': value,
                        };
                      }).toList(),
                      'queryString': Uri.parse(e.uri)
                          .queryParameters
                          .entries
                          .map(
                            (q) => {
                              'name': q.key,
                              'value': q.value,
                            },
                          )
                          .toList(),
                      'postData': {
                        'mimeType': e.contentType,
                        'text': e.requestBody,
                      },
                      'headersSize': -1,
                      'bodySize': -1,
                    },
                    'response': {
                      'status': e.status,
                      'statusText': '',
                      'httpVersion': 'http/2.0',
                      'cookies': e.responseCookies
                          .map(
                            (e) => {
                              'name': e.name,
                              'value': e.value,
                              'path': e.path,
                              'domain': e.domain,
                              'expires': e.expires?.toUtc().toIso8601String(),
                              'httpOnly': e.httpOnly,
                              'secure': e.secure,
                            },
                          )
                          .toList(),
                      'headers': e.responseHeaders?.entries.map((h) {
                        var value = h.value;
                        if (value is List) {
                          value = value.first;
                        }
                        return {
                          'name': h.key,
                          'value': value,
                        };
                      }).toList(),
                      'content': {
                        'size': e.responseBody?.length,
                        'mimeType': e.type,
                        'text': e.responseBody,
                      },
                      'redirectURL': '',
                      'headersSize': -1,
                      'bodySize': -1,
                    },
                    'cache': {},
                    'timings': {
                      'blocked': -1,
                      'dns': -1,
                      'connect': -1,
                      'send': 1,
                      'wait': e.duration!.inMilliseconds - 2,
                      'receive': 1,
                      'ssl': -1,
                    },
                    'serverIPAddress': '10.0.0.1',
                    'connection': e.hashCode.toString(),
                    'comment': '',
                  },
                )
                .toList(),
          },
        };
        debugPrint('data is ${json.encode(har)}');
        return _exportController.downloadFile(
          json.encode(har),
          type: ExportFileType.har,
        );
      }
    } catch (ex) {
      debugPrint('Exception in export $ex');
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

    // If we have updated data for the selected web socket, we need to update
    // the value.
    final currentSelectedRequestId = selectedRequest.value?.id;
    if (currentSelectedRequestId != null) {
      selectedRequest.value =
          currentRequests.getRequest(currentSelectedRequestId);
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
        const Duration(milliseconds: 2000),
        _networkService.refreshNetworkData,
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
    await togglePolling(true);
  }

  Future<void> stopRecording() async {
    await togglePolling(false);
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
    _networkService.updateLastHttpDataRefreshTime();
    await _networkService.updateLastSocketDataRefreshTime();
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

  @override
  OfflineScreenData prepareOfflineScreenData() {
    debugPrint('offline data - httpRequests are $httpRequests');
    return OfflineScreenData(
      screenId: NetworkScreen.id,
      //TODO deserialize har data and pass here
      data: {},
    );
  }
}

/// Class for managing the set of all current websocket requests, and
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
    _updateWebSocketRequests(sockets, timelineMicrosOffset);
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

  void _updateWebSocketRequests(
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
  }

  void clear() {
    _requestsById.clear();
    value = [];
    notifyListeners();
  }
}
