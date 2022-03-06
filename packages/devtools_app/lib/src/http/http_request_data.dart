// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import '../primitives/trace_event.dart';
import '../primitives/utils.dart';
import '../screens/network/network_model.dart';
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import 'http.dart';

class TimelineHttpInstantEvent extends HttpInstantEvent {
  TimelineHttpInstantEvent._(this._event);

  final TraceEvent _event;

  @override
  String? get name => _event.name;

  /// The time the instant event was recorded.
  @override
  int? get timestampMicros => _event.timestampMicros;
}

class DartIOHttpInstantEvent extends HttpInstantEvent {
  DartIOHttpInstantEvent._(this._event);

  final HttpProfileRequestEvent _event;

  @override
  String get name => _event.event;

  /// The time the instant event was recorded.
  @override
  int get timestampMicros => _event.timestamp;
}

/// Used to represent an instant event emitted during an HTTP request.
abstract class HttpInstantEvent {
  String? get name;

  /// The time the instant event was recorded.
  int? get timestampMicros;

  /// The amount of time since the last instant event completed.
  TimeRange? get timeRange => _timeRange;

  // This is set from within HttpRequestData.
  TimeRange? _timeRange;
}

/// An abstraction of an HTTP request made through dart:io.
abstract class HttpRequestData extends NetworkRequest {
  HttpRequestData(int timelineMicrosBase) : super(timelineMicrosBase);

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

  @override
  String? get contentType {
    if (responseHeaders == null ||
        responseHeaders![HttpRequestData._contentTypeKey] == null) {
      return null;
    }
    return responseHeaders![HttpRequestData._contentTypeKey].toString();
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
    if (mime.endsWith(']')) {
      mime = mime.substring(0, mime.length - 1);
    }
    return _extensionFromMime(mime);
  }

  /// Extracts the extension from [mime], with overrides for shortened
  /// extenstions of common types (e.g., jpe -> jpeg).
  String _extensionFromMime(String mime) {
    final extension = extensionFromMime(mime);
    if (extension == 'jpe') {
      return 'jpeg';
    }
    if (extension == 'htm') {
      return 'html';
    }
    // text/plain -> conf
    if (extension == 'conf') {
      return 'txt';
    }
    return extension;
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
  bool get isValid;

  /// True if either the request or response contained cookies.
  bool get hasCookies =>
      requestCookies.isNotEmpty || responseCookies.isNotEmpty;

  /// A map of general information associated with an HTTP request.
  Map<String, dynamic>? get general;

  @override
  int? get port {
    if (general == null) return null;
    final Map<String, dynamic>? connectionInfo =
        general![HttpRequestData._connectionInfoKey];
    return connectionInfo != null
        ? connectionInfo[HttpRequestData._localPortKey]
        : null;
  }

  @override
  bool get didFail {
    if (status == null) return false;
    if (status == 'Error') return true;

    try {
      final code = int.parse(status!);
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

  /// All instant events logged to the timeline for this HTTP request.
  List<HttpInstantEvent> get instantEvents;

  /// A list of all cookies contained within the request headers.
  List<Cookie> get requestCookies;

  /// The request headers for the HTTP request.
  Map<String, dynamic>? get requestHeaders;

  /// A list of all cookies contained within the response headers.
  List<Cookie> get responseCookies;

  /// The response headers for the HTTP request.
  Map<String, dynamic>? get responseHeaders;

  /// UTF-8 Decoded request body
  String? get requestBody;

  /// UTF-8 Decoded response body
  String? get responseBody;

  /// Merges the information from another [HttpRequestData] into this instance.
  void merge(HttpRequestData data);

  static List<Cookie> _parseCookies(List<String>? cookies) {
    if (cookies == null) return [];
    return cookies.map((cookie) => Cookie.fromSetCookieValue(cookie)).toList();
  }
}

/// An abstraction of an HTTP request made through dart:io.
class TimelineHttpRequestData extends HttpRequestData {
  TimelineHttpRequestData._(
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
  factory TimelineHttpRequestData.fromTimeline({
    required int timelineMicrosBase,
    required List<Map<String, dynamic>> requestEvents,
    required List<Map<String, dynamic>> responseEvents,
  }) {
    TraceEvent? requestStartEvent;
    TraceEvent? requestEndEvent;
    String? responseBody;
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

    // Stitch together response as it may have been sent in multiple chunks.
    final encodedData = <int>[];
    for (final event in responseEvents) {
      final traceEvent = TraceEvent(event);
      // TODO(kenz): do we need to do something with the other response events
      // (phases 'b' and 'e')?
      if (traceEvent.phase == TraceEvent.asyncInstantPhase &&
          traceEvent.name == 'Response body') {
        encodedData.addAll((traceEvent.args!['data'] as List).cast<int>());
      }
    }

    try {
      if (encodedData.isNotEmpty) {
        responseBody = utf8.decode(encodedData);
      }
    } on FormatException {
      // Non-UTF8 response.
    }

    final data = TimelineHttpRequestData._(
      timelineMicrosBase,
      requestStartEvent,
      requestEndEvent,
      responseBody,
    );
    data._addInstantEvents(
        requestInstantEvents.map((e) => TimelineHttpInstantEvent._(e)));

    return data;
  }

  final TraceEvent? _startEvent;
  TraceEvent? _endEvent;

  /// For timeline event, HTTP request/response body logging is disabled.
  /// see https://dart-review.googlesource.com/c/sdk/+/189881
  @override
  final String? requestBody = null;

  // TODO(kenz): https://github.com/flutter/devtools/issues/3244
  // Cleanup `TimelineHttpRequestData` and tests in order to allow for :
  // 'final String responseBody = null'
  @override
  final String? responseBody;

  // Do not add to this list directly! Call `_addInstantEvents` which is
  // responsible for calculating the time offsets of each event.
  final List<HttpInstantEvent> _instantEvents = [];

  @override
  Duration? get duration {
    if (inProgress || !isValid) return null;
    // Timestamps are in microseconds
    final range = TimeRange()
      ..start = Duration(microseconds: _startEvent!.timestampMicros!)
      ..end = Duration(microseconds: _endEvent!.timestampMicros!);
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
  // TODO(kenz): https://github.com/flutter/devtools/issues/2335 - figure out
  // how to handle HTTP body events in the network profiler. For now, mark them
  // as invalid.
  @override
  bool get isValid =>
      _startEvent != null &&
      !_startEvent!.name!.contains('HTTP CLIENT response');

  /// A map of general information associated with an HTTP request.
  @override
  Map<String, dynamic> get general {
    if (_general != null) return _general;
    if (!isValid) return null;
    final copy = Map<String, dynamic>.from(_startEvent!.args!);
    if (!inProgress) {
      copy.addAll(_endEvent!.args!);
    }
    copy.remove(HttpRequestData._requestHeadersKey);
    copy.remove(HttpRequestData._responseHeadersKey);
    copy.remove(HttpRequestData._filterKey);
    return _general = copy;
  }

  Map<String, dynamic>? _general;

  /// True if the HTTP request hasn't completed yet, determined by the lack of
  /// an end event.
  @override
  bool get inProgress => _endEvent == null;

  /// All instant events logged to the timeline for this HTTP request.
  @override
  List<HttpInstantEvent> get instantEvents => _instantEvents;

  @override
  String? get method {
    if (!isValid) return null;
    assert(_startEvent!.args!.containsKey(HttpRequestData._methodKey));
    return _startEvent!.args![HttpRequestData._methodKey];
  }

  /// A list of all cookies contained within the request headers.
  @override
  List<Cookie> get requestCookies {
    // The request may still be in progress, in which case we don't display any
    // cookies.
    final headers = requestHeaders;
    if (headers == null) {
      return [];
    }
    return HttpRequestData._parseCookies(
        headers[HttpRequestData._cookieKey] ?? []);
  }

  /// The request headers for the HTTP request.
  @override
  Map<String, dynamic>? get requestHeaders {
    // The request may still be in progress, in which case we don't display any
    // headers, or the request may be invalid, in which case we also don't
    // display any headers.
    if (inProgress || !isValid) return null;
    return _endEvent!.args![HttpRequestData._requestHeadersKey];
  }

  /// The time the HTTP request was issued.
  @override
  DateTime? get startTimestamp {
    if (!isValid) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
      timelineMicrosecondsSinceEpoch(_startEvent!.timestampMicros!),
    );
  }

  @override
  DateTime? get endTimestamp {
    if (inProgress || !isValid) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
        timelineMicrosecondsSinceEpoch(_endEvent!.timestampMicros!));
  }

  /// A list of all cookies contained within the response headers.
  @override
  List<Cookie> get responseCookies {
    // The request may still be in progress, in which case we don't display any
    // cookies.
    final headers = responseHeaders;
    if (headers == null) {
      return [];
    }
    return HttpRequestData._parseCookies(
      headers[HttpRequestData._setCookieKey] ?? [],
    );
  }

  /// The response headers for the HTTP request.
  @override
  Map<String, dynamic>? get responseHeaders {
    // The request may still be in progress, in which case we don't display any
    // headers, or the request may be invalid, in which case we also don't
    // display any headers.
    if (inProgress || !isValid) return null;
    return _endEvent!.args![HttpRequestData._responseHeadersKey];
  }

  /// A string representing the status of the request.
  ///
  /// If the request completed, this will be an HTTP status code. If an error
  /// was encountered, this will return 'Error'.
  @override
  String? get status {
    if (inProgress || !isValid) return null;
    String? statusCode;
    final endArgs = _endEvent!.args!;
    if (endArgs.containsKey(HttpRequestData._errorKey)) {
      // This case occurs when an exception has been thrown, so there's no
      // status code to associate with the request.
      statusCode = 'Error';
    } else {
      statusCode = endArgs[HttpRequestData._statusCodeKey]?.toString();
    }
    return statusCode;
  }

  @override
  String? get uri {
    if (!isValid) return null;
    assert(_startEvent!.args!.containsKey(HttpRequestData._uriKey));
    return _startEvent!.args![HttpRequestData._uriKey];
  }

  /// Merges the information from another [HttpRequestData] into this instance.
  @override
  void merge(HttpRequestData data) {
    assert(data is TimelineHttpRequestData);
    final requestData = data as TimelineHttpRequestData;

    if (data.instantEvents.isNotEmpty) {
      _addInstantEvents(data.instantEvents);
    }
    if (requestData._endEvent != null) {
      _endEvent = requestData._endEvent;
    }
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
    int lastTime = _startEvent!.timestampMicros!;
    for (final instant in instantEvents) {
      final instantTime = instant.timestampMicros!;
      instant._timeRange = TimeRange()
        ..start = Duration(microseconds: lastTime)
        ..end = Duration(microseconds: instantTime);
      lastTime = instantTime;
    }
  }

  @override
  String toString() => '$method $uri';
}

int _dartIoHttpRequestWrapperId = 0;

class DartIOHttpRequestData extends HttpRequestData {
  DartIOHttpRequestData(
    int timelineMicrosBase,
    this._request,
  )   : wrapperId = _dartIoHttpRequestWrapperId++,
        _instantEvents = [],
        super(timelineMicrosBase) {
    if (_request.isResponseComplete) {
      getFullRequestData();
    }
  }

  HttpProfileRequestRef _request;

  final int wrapperId;

  Future<void> getFullRequestData() {
    return serviceManager.service!
        .getHttpProfileRequest(
          _request.isolateId,
          _request.id,
        )
        .then((updated) => _request = updated);
  }

  @visibleForTesting
  int get id => _request.id;

  bool get _hasError => _request.request?.hasError ?? false;

  int? get _endTime =>
      _hasError ? _request.endTime : _request.response!.endTime;

  @override
  Duration? get duration {
    if (inProgress || !isValid) return null;
    // Timestamps are in microseconds
    final range = TimeRange()
      ..start = Duration(microseconds: _request.startTime)
      ..end = Duration(microseconds: _endTime!);
    return range.duration;
  }

  /// Whether the request is safe to display in the UI.
  ///
  /// The dart:io HTTP profiling service extensions should never return invalid
  /// requests.
  @override
  bool get isValid => true;

  /// A map of general information associated with an HTTP request.
  @override
  Map<String, dynamic> get general {
    return {
      'method': _request.method,
      'uri': _request.uri.toString(),
      if (!didFail) ...{
        'connectionInfo': _request.request!.connectionInfo,
        'contentLength': _request.request!.contentLength,
      },
      if (_request.response != null) ...{
        'compressionState': _request.response!.compressionState,
        'isRedirect': _request.response!.isRedirect,
        'persistentConnection': _request.response!.persistentConnection,
        'reasonPhrase': _request.response!.reasonPhrase,
        'redirects': _request.response!.redirects,
        'statusCode': _request.response!.statusCode,
      },
    };
  }

  @override
  String get method => _request.method;

  /// True if the HTTP request hasn't completed yet, determined by the lack of
  /// an end event.
  @override
  bool get inProgress =>
      _hasError ? !_request.isRequestComplete : !_request.isResponseComplete;

  /// All instant events logged to the timeline for this HTTP request.
  @override
  List<HttpInstantEvent> get instantEvents {
    if (_instantEvents == null) {
      _instantEvents = [
        for (final event in _request.request?.events ?? [])
          DartIOHttpInstantEvent._(event)
      ];
      _recalculateInstantEventTimes();
    }
    return _instantEvents!;
  }

  List<HttpInstantEvent>? _instantEvents;

  /// A list of all cookies contained within the request headers.
  @override
  List<Cookie> get requestCookies =>
      _hasError ? [] : HttpRequestData._parseCookies(_request.request?.cookies);

  /// The request headers for the HTTP request.
  @override
  Map<String, dynamic>? get requestHeaders =>
      _hasError ? null : _request.request?.headers;

  /// A list of all cookies contained within the response headers.
  @override
  List<Cookie> get responseCookies =>
      HttpRequestData._parseCookies(_request.response?.cookies);

  /// The response headers for the HTTP request.
  @override
  Map<String, dynamic>? get responseHeaders => _request.response?.headers;

  /// Merges the information from another [HttpRequestData] into this instance.
  @override
  void merge(HttpRequestData data) {
    assert(data is DartIOHttpRequestData);
    final requestData = data as DartIOHttpRequestData;
    _request = requestData._request;
  }

  @override
  DateTime get endTimestamp => DateTime.fromMicrosecondsSinceEpoch(
        timelineMicrosecondsSinceEpoch(_endTime!),
      );

  @override
  DateTime get startTimestamp => DateTime.fromMicrosecondsSinceEpoch(
        timelineMicrosecondsSinceEpoch(_request.startTime),
      );

  @override
  String? get status =>
      _hasError ? 'Error' : _request.response?.statusCode.toString();

  @override
  String get uri => _request.uri.toString();

  @override
  String? get responseBody {
    if (_request is! HttpProfileRequest) {
      return null;
    }
    final fullRequest = _request as HttpProfileRequest;
    try {
      if (!_request.isResponseComplete) return null;
      if (_responseBody != null) return _responseBody;
      _responseBody = utf8.decode(fullRequest.responseBody!);
      if (contentType != null && contentType!.contains('json')) {
        _responseBody = FormattedJson.encoder.convert(
          json.decode(_responseBody!),
        );
      }
      return _responseBody;
    } on FormatException {
      return '<binary data>';
    }
  }

  Uint8List? get encodedResponse {
    if (!_request.isResponseComplete) return null;
    final fullRequest = _request as HttpProfileRequest;
    return fullRequest.responseBody;
  }

  String? _responseBody;

  @override
  String? get requestBody {
    if (_request is! HttpProfileRequest) {
      return null;
    }
    final fullRequest = _request as HttpProfileRequest;
    try {
      if (!_request.isResponseComplete) return null;
      final acceptedMethods = {'POST', 'PUT', 'PATCH'};
      if (!acceptedMethods.contains(_request.method)) return null;
      if (_requestBody != null) return _requestBody;
      _requestBody = utf8.decode(fullRequest.requestBody!);
      return _requestBody;
    } on FormatException {
      return '<binary data>';
    }
  }

  String? _requestBody;

  void _recalculateInstantEventTimes() {
    int lastTime = _request.startTime;
    for (final instant in instantEvents) {
      final instantTime = instant.timestampMicros!;
      instant._timeRange = TimeRange()
        ..start = Duration(microseconds: lastTime)
        ..end = Duration(microseconds: instantTime);
      lastTime = instantTime;
    }
  }

  @override
  bool operator ==(other) {
    return other is DartIOHttpRequestData &&
        wrapperId == other.wrapperId &&
        super == other;
  }

  @override
  int get hashCode => hashValues(
        wrapperId,
        method,
        uri,
        contentType,
        type,
        port,
        startTimestamp,
      );
}
