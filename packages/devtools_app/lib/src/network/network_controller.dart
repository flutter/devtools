// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../ui/fake_flutter/fake_flutter.dart';
import '../globals.dart';
import '../utils.dart';

class HttpRequestData {
  HttpRequestData(this._startEvent, this._endEvent, this._instantEvents);

  factory HttpRequestData._fromTimeline(List<Map> events) {
    Map startEvent;
    Map endEvent;
    List<Map> instantEvents = [];

    for (final event in events) {
      const kStart = 'b';
      const kEnd = 'e';
      const kInstant = 'n';
      final type = event['ph'];
      if (type == kStart) {
        assert(startEvent == null);
        startEvent = event;
      } else if (type == kEnd) {
        assert(endEvent == null);
        endEvent = event;
      } else if (type == kInstant) {
        instantEvents.add(event);
      } else {
        assert(false, 'Unexpected event type: $type');
      }
    }

    assert(startEvent != null);

    // TODO(bkonyi): handle null case

    return HttpRequestData(startEvent, endEvent, instantEvents);
  }

  Uri get uri {
    assert(_startEvent['args'].containsKey('uri'));
    return Uri.parse(_startEvent['args']['uri']);
  }

  int get status {
    int statusCode;
    if (_endEvent != null) {
      final endArgs = _endEvent['args'];
      if (endArgs.containsKey('error')) {
        // TODO(bkonyi): get proper status codes from error. Assume connection
        // refused (502) for now.
        statusCode = 502;
      } else {
        statusCode = endArgs['statusCode'];
      }
    }
    return statusCode;
  }

  double get durationMs {
    if (_endEvent == null) {
      return null;
    }
    // Timestamps are in microseconds
    double millis = (_endEvent['ts'] - _startEvent['ts']) / 1000;
    if (millis >= 1.0) {
      millis = millis.truncateToDouble();
    }
    return millis;
  }

  String get name => uri.toString();

  String get method {
    assert(_startEvent['args'].containsKey('method'));
    return _startEvent['args']['method'];
  }

  Map get general {
    final copy = Map.from(_startEvent['args']);
    if (_endEvent != null) {
      copy.addAll(_endEvent['args']);
    }
    copy.remove('requestHeaders');
    copy.remove('responseHeaders');
    copy.remove('filterKey');
    return copy;
  }

  Map get requestHeaders {
    if (_endEvent == null) {
      return null;
    }
    return _endEvent['args']['requestHeaders'];
  }

  Map get responseHeaders {
    if (_endEvent == null) {
      return null;
    }
    return _endEvent['args']['responseHeaders'];
  }

  final Map _startEvent;
  final Map _endEvent;
  final List<Map> _instantEvents;

  bool selected = false;
}

class NetworkController {
  /// Notifies that the timeline is currently being recorded.
  ValueListenable get requestsNotifier => _httpRequestsNotifier;
  final _httpRequestsNotifier = ValueNotifier<List<HttpRequestData>>([]);

  ValueListenable get recordingNotifier => _httpRecordingNotifier;
  final _httpRecordingNotifier = ValueNotifier<bool>(false);

  int _profileStartMicros = 0;

  void _processHttpTimelineEvents(Timeline timeline) {
    final events = timeline.traceEvents;
    final httpEventIds = <String>{};
    // Perform initial pass to find the IDs for the HTTP timeline events.
    for (final TimelineEvent event in events) {
      final json = event.toJson();
      if (!json['args'].containsKey('filterKey') ||
          json['args']['filterKey'] != 'HTTP/client') {
        continue;
      }
      httpEventIds.add(json['id']);
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
    // TODO(bkonyi): handle case where we have entries from a prior refresh
    // that are now completed.
    // Build our list of network requests from the collected events.
    _httpRequestsNotifier.value.addAll([
      for (final request in httpEvents.values)
        HttpRequestData._fromTimeline(request)
    ]);
    // Trigger refresh.
    //_httpRequestsNotifier.value = _httpRequestsNotifier.value;
    // TODO(bkonyi): figure out a better way to notify listeners.
    _httpRequestsNotifier.notifyListeners();
  }

  _startPolling() {
    Future<void>.delayed(const Duration(milliseconds: 5000)).then((_) {
      if (_httpRecordingNotifier.value) {
        refreshRequests();
        _startPolling();
      }
    });
  }

  Future<LibraryRef> _findDartHttp(IsolateRef isolateRef) async {
    final result = await serviceManager.service.getIsolate(isolateRef.id);
    if (result is Sentinel) {
      return null;
    }
    final isolate = result as Isolate;

    // Look for dart:io library in the isolate and then find HttpClient.
    for (final libRef in isolate.libraries) {
      if (libRef.name == 'dart.io') {
        return libRef;
      }
    }
    return null;
  }

  // TODO(bkonyi): get state at startup
  Future<void> _setHttpTimelineRecording(bool state) async {
    print('setHttpTimelineRecording');
    // TODO(bkonyi): figure out why I can't access dart:_http fields
    /*final vm = await serviceManager.service.getVM();
    for (final isolateRef in vm.isolates) {
      final libRef = await _findDartHttp(isolateRef);
      if (libRef == null) {
        continue;
      }

      final result = await serviceManager.service.evaluate(isolateRef.id,
          libRef.id, 'HttpClient.enableTimelineLogging = $state');
      if (result is! InstanceRef) {
        // TODO(bkonyi): log error?
      }
    }
    print("SETTING IS RECORDING: $state");*/
    _httpRecordingNotifier.value = state;
  }

  /// Returns true is ** at least one ** isolate is recording HTTP events.
  /*Future<bool> _getHttpTimelineRecording() async {
    print("GET HTTP TIMELINE RECORDING");
    final vm = await serviceManager.service.getVM();
    for (final isolateRef in vm.isolates) {
      print("ISOLATE");
      final libRef = await _findDartHttp(isolateRef);
      if (libRef == null) {
        print("libRef NULL");
        continue;
      }

      print("HERE");
      try {
        final result = await serviceManager.service.evaluate(
            isolateRef.id, libRef.id, 'HttpClient.enableTimelineLogging');
        print("RESULT: $result");
        if (result is! InstanceRef) {
          print("RESULT IS NOT INSTANCE");
          // TODO(bkonyi): log error?
        }
        final boolean = result as InstanceRef;
        print('Result: $boolean');
        if (boolean.valueAsString == 'true') {
          return true;
        }
      } catch (e) {
        print("ERROR: $e");
      }
    }
    print("Not recording\n");
    return false;
  }*/

  Future<void> refreshRequests() async {
    print("refresh");
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    final timeline = await serviceManager.service.getVMTimeline(
        timeOriginMicros: _profileStartMicros,
        timeExtentMicros: timestamp.timestamp);
    _profileStartMicros = timestamp.timestamp;
    _processHttpTimelineEvents(timeline);
  }

  Future<void> startRecording() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    _profileStartMicros = timestamp.timestamp;
    await _setHttpTimelineRecording(true);
    _startPolling();
  }

  Future<void> pauseRecording() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    await _setHttpTimelineRecording(false);
  }

  Future<void> clear() async {
    final timestamp = await serviceManager.service.getVMTimelineMicros();
    _profileStartMicros = timestamp.timestamp;
    _httpRequestsNotifier.value = [];
  }
}
