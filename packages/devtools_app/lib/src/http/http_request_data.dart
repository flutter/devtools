// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import '../config_specific/logger/logger.dart';
import '../network/network_model.dart';
import '../trace_event.dart';
import '../utils.dart';
import 'http.dart';

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
class HttpRequestData extends NetworkRequest {
  HttpRequestData._(
    int timelineMicrosBase,
    this._startEvent,
    this._endEvent,
    this.responseBody,
  ) : super(timelineMicrosBase);

  /// Build an instance from timeline events.
  ///
  /// `timelineMicrosBase` is the offset used to determine the wall-time of a
  /// timeline event. `events` is a list of Chrome trace format timeline
  /// events.
  factory HttpRequestData.fromTimeline({
    @required int timelineMicrosBase,
    @required List<Map<String, dynamic>> requestEvents,
    @required List<Map<String, dynamic>> responseEvents,
  }) {
    TraceEvent requestStartEvent;
    TraceEvent requestEndEvent;
    String responseBody;
    final requestInstantEvents = <TraceEvent>[];

    for (final event in requestEvents) {
      final traceEvent = TraceEvent(event);
      if (traceEvent.phase == TraceEvent.asyncBeginPhase) {
        assert(requestStartEvent == null);
        requestStartEvent = traceEvent;
      } else if (traceEvent.phase == TraceEvent.asyncEndPhase) {
        assert(requestEndEvent == null);
        requestEndEvent = traceEvent;
      } else if (traceEvent.phase == TraceEvent.asyncInstantPhase) {
        requestInstantEvents.add(traceEvent);
      } else {
        assert(false, 'Unexpected event type: ${traceEvent.phase}');
      }
    }

    for (final event in responseEvents) {
      final traceEvent = TraceEvent(event);
      // TODO(kenz): do we need to do something with the other response events
      // (phases 'b' and 'e')?
      if (traceEvent.phase == TraceEvent.asyncInstantPhase &&
          traceEvent.name == 'Response body') {
        final encodedData = (traceEvent.args['data'] as List).cast<int>();
        responseBody = utf8.decode(encodedData);
        break;
      }
    }

    final data = HttpRequestData._(
      timelineMicrosBase,
      requestStartEvent,
      requestEndEvent,
      responseBody,
    );
    data._addInstantEvents(
        requestInstantEvents.map((e) => HttpInstantEvent._(e)));

    return data;
  }

  static const _connectionInfoKey = 'connectionInfo';
  static const _contentTypeKey = 'content-type';
  static const _cookieKey = 'cookie';
  static const _errorKey = 'error';
  static const _filterKey = 'filterKey';
  static const _localPortKey = 'localPort';
  static const _methodKey = 'method';
  static const _requestHeadersKey = 'requestHeaders';
  static const _responseHeadersKey = 'responseHeaders';
  static const _statusCodeKey = 'statusCode';
  // TODO(kenz): modify this to `setCookie` once
  // https://github.com/dart-lang/sdk/issues/42822 is resolved
  static const _setCookieKey = 'set-cookie';
  static const _uriKey = 'uri';

  final TraceEvent _startEvent;
  TraceEvent _endEvent;
  final String responseBody;

  // Do not add to this list directly! Call `_addInstantEvents` which is
  // responsible for calculating the time offsets of each event.
  final List<HttpInstantEvent> _instantEvents = [];

  @override
  Duration get duration {
    if (inProgress || !isValid) return null;
    // Timestamps are in microseconds
    final range = TimeRange()
      ..start = Duration(microseconds: _startEvent.timestampMicros)
      ..end = Duration(microseconds: _endEvent.timestampMicros);
    return range.duration;
  }

  @override
  String get contentType {
    if (responseHeaders == null || responseHeaders[_contentTypeKey] == null) {
      return null;
    }
    return responseHeaders[_contentTypeKey].toString();
  }

  @override
  String get type {
    var mime = contentType;
    if (mime == null) return 'http';

    // Extract the MIME from `contentType`.
    // Example: "[text/html; charset-UTF-8]" --> "text/html"
    mime = mime.split(';').first;
    if (mime.startsWith('[')) {
      mime = mime.substring(1);
    }
    // TODO(kenz): consider special casing some extensions. For example,
    // "text/html" is the MIME for both .html and .htm, but since .htm comes
    // first alphabetically, `extensionFromMime` returns "htm". Other cases are
    // more unintuitive such as "text/plain" returning "conf".
    return extensionFromMime(mime);
  }

  /// Whether the request is safe to display in the UI.
  ///
  /// It is possible to get invalid events if we receive an endEvent but no
  /// matching start event due when we started tracking network traffic. These
  /// invalid requests will never complete so it wouldn't make sense to work
  /// around the issue by displaying them as "in-progress". It would be
  /// reasonable to display them as "unknown start time" but that seems like
  /// more complexity than it is worth.
  // TODO(kenz): https://github.com/flutter/devtools/issues/2335 - figure out
  // how to handle HTTP body events in the network profiler. For now, mark them
  // as invalid.
  bool get isValid =>
      _startEvent != null && !_startEvent.name.contains('HTTP CLIENT response');

  /// True if either the request or response contained cookies.
  bool get hasCookies =>
      requestCookies.isNotEmpty || responseCookies.isNotEmpty;

  /// A map of general information associated with an HTTP request.
  Map<String, dynamic> get general {
    if (_general != null) return _general;
    if (!isValid) return null;
    final copy = Map<String, dynamic>.from(_startEvent.args);
    if (!inProgress) {
      copy.addAll(_endEvent.args);
    }
    copy.remove(_requestHeadersKey);
    copy.remove(_responseHeadersKey);
    copy.remove(_filterKey);
    return _general = copy;
  }

  Map<String, dynamic> _general;

  @override
  int get port {
    if (general == null) return null;
    final Map<String, dynamic> connectionInfo = general[_connectionInfoKey];
    return connectionInfo != null ? connectionInfo[_localPortKey] : null;
  }

  @override
  bool get didFail {
    if (status == null) return false;
    if (status == 'Error') return true;

    try {
      final code = int.parse(status);
      // Status codes 400-499 are client errors and 500-599 are server errors.
      if (code >= 400) {
        return true;
      }
    } on Exception catch (_) {
      log(
        'Could not parse HTTP request status: $status',
        LogLevel.error,
      );
      return true;
    }
    return false;
  }

  /// True if the HTTP request hasn't completed yet, determined by the lack of
  /// an end event.
  bool get inProgress => _endEvent == null;

  /// All instant events logged to the timeline for this HTTP request.
  List<HttpInstantEvent> get instantEvents => _instantEvents;

  @override
  String get method {
    if (!isValid) return null;
    assert(_startEvent.args.containsKey(_methodKey));
    return _startEvent.args[_methodKey];
  }

  /// A list of all cookies contained within the request headers.
  List<Cookie> get requestCookies {
    // The request may still be in progress, in which case we don't display any
    // cookies.
    final headers = requestHeaders;
    if (headers == null) {
      return [];
    }
    return _parseCookies(headers[_cookieKey] ?? []);
  }

  /// The request headers for the HTTP request.
  Map<String, dynamic> get requestHeaders {
    // The request may still be in progress, in which case we don't display any
    // headers, or the request may be invalid, in which case we also don't
    // display any headers.
    if (inProgress || !isValid) return null;
    return _endEvent.args[_requestHeadersKey];
  }

  /// The time the HTTP request was issued.
  @override
  DateTime get startTimestamp {
    if (!isValid) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
      timelineMicrosecondsSinceEpoch(_startEvent.timestampMicros),
    );
  }

  @override
  DateTime get endTimestamp {
    if (inProgress || !isValid) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
        timelineMicrosecondsSinceEpoch(_endEvent.timestampMicros));
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
      headers[_setCookieKey] ?? [],
    );
  }

  /// The response headers for the HTTP request.
  Map<String, dynamic> get responseHeaders {
    // The request may still be in progress, in which case we don't display any
    // headers, or the request may be invalid, in which case we also don't
    // display any headers.
    if (inProgress || !isValid) return null;
    return _endEvent.args[_responseHeadersKey];
  }

  /// A string representing the status of the request.
  ///
  /// If the request completed, this will be an HTTP status code. If an error
  /// was encountered, this will return 'Error'.
  @override
  String get status {
    if (inProgress || !isValid) return null;
    String statusCode;
    final endArgs = _endEvent.args;
    if (endArgs.containsKey(_errorKey)) {
      // This case occurs when an exception has been thrown, so there's no
      // status code to associate with the request.
      statusCode = 'Error';
    } else {
      statusCode = endArgs[_statusCodeKey]?.toString();
    }
    return statusCode;
  }

  @override
  String get uri {
    if (!isValid) return null;
    assert(_startEvent.args.containsKey(_uriKey));
    return _startEvent.args[_uriKey];
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
    return cookies.map((cookie) => Cookie.fromSetCookieValue(cookie)).toList();
  }

  void _addInstantEvents(Iterable<HttpInstantEvent> events) {
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

  @override
  String toString() => '$method $uri';
}
