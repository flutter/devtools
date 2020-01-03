// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'http.dart';

/// Contains all state relevant to completed and in-progress HTTP requests.
class HttpRequests {
  HttpRequests({this.requests, this.outstanding}) {
    requests ??= [];
    outstanding ??= {};
  }

  void clear() {
    requests.clear();
    outstanding.clear();
  }

  List<HttpRequestData> requests;

  /// A mapping of timeline IDs to instances of HttpRequestData which are
  /// currently in-progress.
  Map<String, HttpRequestData> outstanding;
}

/// Used to represent an instant event emitted during an HTTP request.
class HttpInstantEvent {
  HttpInstantEvent._(this._rawEvent) : name = _rawEvent['name'];

  final Map _rawEvent;
  final String name;

  /// The amount of time since the last instant event completed.
  double get timeDiffMs => _timeDiffMs;
  
  // This is set from within HttpRequestData.
  double _timeDiffMs;
}

/// An abstraction of an HTTP request made through dart:io.
class HttpRequestData {
  HttpRequestData._(this._timelineMicrosBase, this._startEvent, this._endEvent);

  /// Build an instance from timeline events.
  /// 
  /// `timelineMicrosBase` is the offset used to determine the wall-time of a
  /// timeline event. `events` is a list of Chrome trace format timeline
  /// events.
  factory HttpRequestData.fromTimeline(
      int timelineMicrosBase, List<Map> events) {
    Map startEvent;
    Map endEvent;
    final instantEvents = <Map>[];

    for (final event in events) {
      if (_isStartEvent(event)) {
        assert(startEvent == null);
        startEvent = event;
      } else if (_isEndEvent(event)) {
        assert(endEvent == null);
        endEvent = event;
      } else if (_isInstantEvent(event)) {
        instantEvents.add(event);
      } else {
        assert(false, 'Unexpected event type');
      }
    }
    final data = HttpRequestData._(timelineMicrosBase, startEvent, endEvent);
    data._addInstantEvents(
        [for (final instant in instantEvents) HttpInstantEvent._(instant)]);
    return data;
  }

  /// Merges the information from another [HttpRequestData] into this instance.
  void merge(HttpRequestData data) {
    if (data.instantEvents.isNotEmpty) {
      _addInstantEvents(data.instantEvents);
    }
    if (data._endEvent != null) {
      _endEvent = data._endEvent;
    }
  }

  // Timeline event helpers.
  static bool _isStartEvent(Map event) => event['ph'] == 'b';
  static bool _isEndEvent(Map event) => event['ph'] == 'e';
  static bool _isInstantEvent(Map event) => event['ph'] == 'n';

  static List<Cookie> _parseCookies(List cookies) {
    return [for (final cookie in cookies) Cookie.fromSetCookieValue(cookie)];
  }

  void _addInstantEvents(List<HttpInstantEvent> events) {
    _instantEvents.addAll(events);

    // This event is the second half of an outstanding request which will be
    // merged into a single HttpRequestData elsewhere. We'll calculate the
    // instant event times then since we'll have _startEvent's timestamp.
    if (_startEvent == null) {
      return;
    }
    _recalculateInstantEventTimes();
  }

  void _recalculateInstantEventTimes() {
    assert(_startEvent != null);
    int lastTime = _requestTimeMicros;
    for (final instant in instantEvents) {
      final instantTime = _getTimelineMicrosecondsSinceEpoch(instant._rawEvent);
      instant._timeDiffMs = (instantTime - lastTime) / 1000;
      lastTime = instantTime;
    }
  }

  int _getTimelineMicrosecondsSinceEpoch(Map event) {
    assert(event.containsKey('ts'));
    return _timelineMicrosBase + event['ts'];
  }

  /// The duration of the HTTP request, in milliseconds.
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

  /// True if either the request or response contained cookies.
  bool get hasCookies =>
      requestCookies.isNotEmpty || responseCookies.isNotEmpty;

  /// A map of general information associated with an HTTP request.
  Map<String, dynamic> get general {
    final copy = Map.from(_startEvent['args']);
    if (_endEvent != null) {
      copy.addAll(_endEvent['args']);
    }
    copy.remove('requestHeaders');
    copy.remove('responseHeaders');
    copy.remove('filterKey');
    return copy;
  }

  /// True if the HTTP request hasn't completed yet, determined by the lack of
  /// an end event.
  bool get inProgress => _endEvent == null;

  /// All instant events logged to the timeline for this HTTP request.
  List<HttpInstantEvent> get instantEvents => _instantEvents;

  /// The HTTP methods associated with this request.
  String get method {
    assert(_startEvent['args'].containsKey('method'));
    return _startEvent['args']['method'];
  }

  /// The name of the request (currently the URI).
  String get name => uri.toString();

  /// A list of all cookies contained within the request headers.
  List<Cookie> get requestCookies {
    final headers = requestHeaders;
    if (headers == null) {
      return [];
    }
    return _parseCookies(headers['cookie'] ?? []);
  }

  /// The request headers for the HTTP request.
  Map<String, dynamic> get requestHeaders {
    if (_endEvent == null) {
      return null;
    }
    return _endEvent['args']['requestHeaders'];
  }

  /// The time the HTTP request was issued.
  DateTime get requestTime {
    assert(_startEvent != null);
    return DateTime.fromMicrosecondsSinceEpoch(_requestTimeMicros);
  }

  int get _requestTimeMicros {
    assert(_startEvent != null);
    return _getTimelineMicrosecondsSinceEpoch(_startEvent);
  }

  /// A list of all cookies contained within the response headers.
  List<Cookie> get responseCookies {
    final headers = responseHeaders;
    if (headers == null) {
      return [];
    }
    return _parseCookies(headers['set-cookie'] ?? []);
  }

  /// The response headers for the HTTP request.
  Map<String, dynamic> get responseHeaders {
    if (_endEvent == null) {
      return null;
    }
    return _endEvent['args']['responseHeaders'];
  }

  /// A string representing the status of the request.
  /// 
  /// If the request completed, this will be an HTTP status code. If an error
  /// was encountered, this will return 'Error'.
  String get status {
    String statusCode;
    if (_endEvent != null) {
      final endArgs = _endEvent['args'];
      if (endArgs.containsKey('error')) {
        // This case occurs when an exception has been thrown, so there's no
        // status code to associate with the request.
        statusCode = 'Error';
      } else {
        statusCode = endArgs['statusCode'].toString();
      }
    }
    return statusCode;
  }

  /// The address the HTTP request was issued to.
  Uri get uri {
    assert(_startEvent['args'].containsKey('uri'));
    return Uri.parse(_startEvent['args']['uri']);
  }

  final int _timelineMicrosBase;
  final Map _startEvent;
  Map _endEvent;

  // Do not add to this list directly! Call `_addInstantEvents` which is
  // responsible for calculating the time offsets of each event.
  final List<HttpInstantEvent> _instantEvents = [];

  // State used to determine whether this request is currently selected in a
  // table.
  bool selected = false;
}
