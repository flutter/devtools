// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../trace_event.dart';
import '../utils.dart';

import 'http.dart';

/// Contains all state relevant to completed and in-progress HTTP requests.
class HttpRequests {
  HttpRequests({
    this.requests = const [],
    this.invalidRequests = const [],
    this.outstandingRequests = const {},
  })  : assert(requests != null),
        assert(invalidRequests != null),
        assert(outstandingRequests != null);

  /// A list of HTTP requests.
  ///
  /// Individual requests in this list can be either completed or in-progress.
  List<HttpRequestData> requests;

  /// A list of invalid HTTP requests received.
  ///
  /// These are requests that have completed but do not contain all the required
  /// information to display normally in the UI.
  List<HttpRequestData> invalidRequests;

  /// A mapping of timeline IDs to instances of HttpRequestData which are
  /// currently in-progress.
  Map<String, HttpRequestData> outstandingRequests;

  void clear() {
    requests.clear();
    outstandingRequests.clear();
  }
}

/// Used to represent an instant event emitted during an HTTP request.
class HttpInstantEvent {
  HttpInstantEvent._(this._event);

  final TraceEvent _event;
  String get name => _event.name;

  /// The time the instant event was recorded.
  int get timestampMicros => _event.timestampMicros;

  /// The amount of time since the last instant event completed.
  TimeRange get timeRange => _timeRange;

  // This is set from within HttpRequestData.
  TimeRange _timeRange;
}

/// An abstraction of an HTTP request made through dart:io.
class HttpRequestData {
  HttpRequestData._(
    this._timelineMicrosBase,
    this._startEvent,
    this._endEvent,
  );

  /// Build an instance from timeline events.
  ///
  /// `timelineMicrosBase` is the offset used to determine the wall-time of a
  /// timeline event. `events` is a list of Chrome trace format timeline
  /// events.
  factory HttpRequestData.fromTimeline(
    int timelineMicrosBase,
    List<Map<String, dynamic>> events,
  ) {
    TraceEvent startEvent;
    TraceEvent endEvent;
    final instantEvents = <TraceEvent>[];

    for (final event in events) {
      final traceEvent = TraceEvent(event);
      if (traceEvent.phase == TraceEvent.asyncBeginPhase) {
        assert(startEvent == null);
        startEvent = traceEvent;
      } else if (traceEvent.phase == TraceEvent.asyncEndPhase) {
        assert(endEvent == null);
        endEvent = traceEvent;
      } else if (traceEvent.phase == TraceEvent.asyncInstantPhase) {
        instantEvents.add(traceEvent);
      } else {
        assert(false, 'Unexpected event type: ${traceEvent.phase}');
      }
    }
    final data = HttpRequestData._(
      timelineMicrosBase,
      startEvent,
      endEvent,
    );
    data._addInstantEvents(
      [
        for (final instant in instantEvents)
          HttpInstantEvent._(
            instant,
          ),
      ],
    );
    return data;
  }

  final int _timelineMicrosBase;
  final TraceEvent _startEvent;
  TraceEvent _endEvent;

  // Do not add to this list directly! Call `_addInstantEvents` which is
  // responsible for calculating the time offsets of each event.
  final List<HttpInstantEvent> _instantEvents = [];

  // State used to determine whether this request is currently selected in a
  // table.
  bool selected = false;

  /// The duration of the HTTP request, in milliseconds.
  Duration get duration {
    if (_endEvent == null || _startEvent == null) {
      return null;
    }
    // Timestamps are in microseconds
    final range = TimeRange()
      ..start = Duration(microseconds: _startEvent.timestampMicros)
      ..end = Duration(microseconds: _endEvent.timestampMicros);
    return range.duration;
  }

  /// Whether the request is safe to display in the UI.
  ///
  /// It is possible to get invalid events if we receive an endEvent but no
  /// matching start event due when we started tracking network traffic. These
  /// invalid requests will never complete so it wouldn't make sense to work
  /// around the issue by displaying them as "in-progress". It would be
  /// reasonable to display them as "unknown start time" but that seems like
  /// more complexity than it is worth.
  bool get isValid => _startEvent != null;

  /// True if either the request or response contained cookies.
  bool get hasCookies =>
      requestCookies.isNotEmpty || responseCookies.isNotEmpty;

  /// A map of general information associated with an HTTP request.
  Map<String, dynamic> get general {
    final copy = Map<String, dynamic>.from(_startEvent.args);
    if (_endEvent != null) {
      copy.addAll(_endEvent.args);
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

  /// The HTTP method associated with this request.
  String get method {
    assert(_startEvent.args.containsKey('method'));
    return _startEvent.args['method'];
  }

  /// The name of the request (currently the URI).
  String get name => uri.toString();

  /// A list of all cookies contained within the request headers.
  List<Cookie> get requestCookies {
    // The request may still be in progress, in which case we don't display any
    // cookies.
    final headers = requestHeaders;
    if (headers == null) {
      return [];
    }
    return _parseCookies(headers['cookie'] ?? []);
  }

  /// The request headers for the HTTP request.
  Map<String, dynamic> get requestHeaders {
    // The request may still be in progress, in which case we don't display any
    // headers.
    if (_endEvent == null) {
      return null;
    }
    return _endEvent.args['requestHeaders'];
  }

  /// The time the HTTP request was issued.
  DateTime get requestTime {
    assert(_startEvent != null);
    return DateTime.fromMicrosecondsSinceEpoch(
      _getTimelineMicrosecondsSinceEpoch(_startEvent),
    );
  }

  /// A list of all cookies contained within the response headers.
  List<Cookie> get responseCookies {
    // The request may still be in progress, in which case we don't display any
    // cookies.
    final headers = responseHeaders;
    if (headers == null) {
      return [];
    }
    return _parseCookies(
      headers['set-cookie'] ?? [],
    );
  }

  /// The response headers for the HTTP request.
  Map<String, dynamic> get responseHeaders {
    // The request may still be in progress, in which case we don't display any
    // headers.
    if (_endEvent == null) {
      return null;
    }
    return _endEvent.args['responseHeaders'];
  }

  /// A string representing the status of the request.
  ///
  /// If the request completed, this will be an HTTP status code. If an error
  /// was encountered, this will return 'Error'.
  String get status {
    String statusCode;
    if (_endEvent != null) {
      final endArgs = _endEvent.args;
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
    assert(_startEvent.args.containsKey('uri'));
    return Uri.parse(_startEvent.args['uri']);
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

  static List<Cookie> _parseCookies(List cookies) {
    return [
      for (final cookie in cookies) Cookie.fromSetCookieValue(cookie),
    ];
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
    int lastTime = _startEvent.timestampMicros;
    for (final instant in instantEvents) {
      final instantTime = instant.timestampMicros;
      instant._timeRange = TimeRange()
        ..start = Duration(microseconds: lastTime)
        ..end = Duration(microseconds: instantTime);
      lastTime = instantTime;
    }
  }

  int _getTimelineMicrosecondsSinceEpoch(TraceEvent event) {
    return _timelineMicrosBase + event.timestampMicros;
  }
}
